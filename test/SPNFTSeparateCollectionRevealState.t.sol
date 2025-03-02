// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./SPNFTRevealEnabledState.t.sol";

/**
 * @title SPNFTSeparateCollectionRevealState
 * @dev State with separate collection reveal type set and one token revealed
 */
abstract contract SPNFTSeparateCollectionRevealState is
    SPNFTRevealEnabledState
{
    uint256 internal requestId;

    function setUp() public virtual override {
        super.setUp();

        // Set reveal type to separate collection
        vm.startPrank(deployer);
        spnft.setRevealEnabled(false);
        spnft.setRevealType(SPNFT.RevealType.SeparateCollection);
        spnft.setRevealEnabled(true);
        vm.stopPrank();

        // Request reveal for token1
        requestId = 123;

        // Mock the VRF call
        vm.mockCall(
            mockVrfCoordinator,
            abi.encodeWithSelector(
                VRFCoordinatorV2Interface.requestRandomWords.selector
            ),
            abi.encode(requestId)
        );

        vm.prank(user1);
        spnft.requestReveal(tokenId1);

        // Simulate the VRF callback
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;

        // Use the helper function to simulate VRF callback
        _simulateVRFCallback(requestId, 12345);
    }
}

/**
 * @title SPNFTSeparateCollectionRevealTest
 * @dev Test contract for separate collection reveal
 */
contract SPNFTSeparateCollectionRevealTest is
    SPNFTSeparateCollectionRevealState
{
    function testRevealedCollectionAddressSet() public {
        assertEq(spnft.revealedCollectionAddress(), address(revealedSpnft));
    }

    function testTokenMovedToRevealedCollection() public {
        // With separate collection reveal, the token should be burned in original collection
        vm.expectRevert();
        spnft.ownerOf(tokenId1);

        // And should now exist in the revealed collection
        assertEq(revealedSpnft.ownerOf(tokenId1), user1);
    }

    function testRevealedTokenURI() public {
        // Get URI from revealed collection
        string memory uri = revealedSpnft.tokenURI(tokenId1);

        string memory expectedURI = spnft.generateRevealedMetadata(tokenId1);

        assertEq(uri, expectedURI);
    }

    function testUnrevealedTokenStillInOriginalCollection() public {
        // Token2 hasn't been revealed yet, so should still be in the original collection
        assertEq(spnft.ownerOf(tokenId2), user1);

        // And should show mystery box metadata
        string memory uri = spnft.tokenURI(tokenId2);
        string memory expectedURI = spnft.generateUnrevealedMetadata(tokenId2);

        assertEq(uri, expectedURI);
    }

    function testTokenRevealStatus() public {
        // Create an explicit cast to access the exposed functions
        SPNFTWithExposedVRF spnftCast = SPNFTWithExposedVRF(address(spnft));

        // Check if token2 (unrevealed) has randomness
        assertEq(spnftCast.isRevealed(tokenId2), false);

        // We can't check token1 in the original contract since it's burned
        // But we can verify it exists in the revealed collection
        assertTrue(revealedSpnft.ownerOf(tokenId1) == user1);

        // Request reveal for token2
        uint256 newRequestId = 456;

        // Mock the VRF call
        vm.mockCall(
            mockVrfCoordinator,
            abi.encodeWithSelector(
                VRFCoordinatorV2Interface.requestRandomWords.selector
            ),
            abi.encode(newRequestId)
        );

        vm.prank(user1);
        spnft.requestReveal(tokenId2);

        // Check token is not revealed yet
        assertEq(spnftCast.isRevealed(tokenId2), false);

        // Simulate VRF callback
        _simulateVRFCallback(newRequestId, 67890);

        // After callback, token should be revealed (and transferred to revealed collection)
        vm.expectRevert();
        spnft.ownerOf(tokenId2);

        // Verify token exists in revealed collection
        assertEq(revealedSpnft.ownerOf(tokenId2), user1);
    }
}
