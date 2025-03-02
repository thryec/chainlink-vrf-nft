// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./SPNFTRevealEnabledState.t.sol";

/**
 * @title SPNFTInCollectionRevealState
 * @dev State with in-collection reveal type set and one token revealed
 */
abstract contract SPNFTInCollectionRevealState is SPNFTRevealEnabledState {
    uint256 internal requestId;

    function setUp() public virtual override {
        super.setUp();

        // Set reveal type to in-collection (it's already the default, but setting explicitly for clarity)
        vm.startPrank(deployer);
        // Disable temporarily to set reveal type
        spnft.setRevealEnabled(false);
        // Set reveal type to in-collection
        spnft.setRevealType(SPNFT.RevealType.InCollection);
        // Enable revealing again
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
 * @title SPNFTInCollectionRevealTest
 * @dev Test contract for in-collection reveal
 */
contract SPNFTInCollectionRevealTest is SPNFTInCollectionRevealState {
    function testTokenRemainsWithSameOwner() public {
        // After reveal with in-collection approach, the token should still be owned by user1
        assertEq(spnft.ownerOf(tokenId1), user1);
    }

    function testTokenUriChanged() public {
        // Token1 should now show revealed metadata
        string memory uri = spnft.tokenURI(tokenId1);

        console.log("new uri:", uri);
        string memory expectedURI = spnft.generateRevealedMetadata(tokenId1);

        assertEq(uri, expectedURI);
    }

    function testUnrevealedTokenStillShowsMysteryBox() public {
        // Token2 hasn't been revealed yet, so should still show mystery box metadata
        string memory uri = spnft.tokenURI(tokenId2);

        string memory expectedURI = spnft.generateUnrevealedMetadata(tokenId2);

        assertEq(uri, expectedURI);
    }
}
