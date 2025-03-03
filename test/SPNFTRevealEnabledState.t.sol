// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./SPNFTMintedState.t.sol";
import "./SPNFTWithExposedVRF.sol";

/**
 * @title SPNFTRevealEnabledState
 * @dev State with SPNFT tokens minted and revealing enabled but tokens not yet revealed
 */
abstract contract SPNFTRevealEnabledState is SPNFTMintedState {
    // // We need to "override" the spnft variable with our VRF-exposed version
    // SPNFTWithExposedVRF internal spnftWithVRF;

    function setUp() public virtual override {
        // First run the parent setUp (which will deploy regular SPNFT and set up the VRF)
        super.setUp();

        vm.startPrank(deployer);

        // Configure it the same way
        spnft.setMetadata(names, descriptions, images, attributes);
        spnft.setRevealedCollectionAddress(address(revealedSpnft));
        spnft.setMintEnabled(true);

        // Update the RevealedSPNFT to use our new contract
        revealedSpnft.setSPNFTContract(address(spnft));

        // Enable revealing
        spnft.setRevealEnabled(true);

        vm.stopPrank();

        // Mint the same tokens again to the same users
        // (We could also transfer tokens from the original contract, but this is simpler)
        _dealTokens(user1, mintPrice * 2);
        _dealTokens(user2, mintPrice);

        vm.startPrank(user1);
        tokenId1 = spnft.mint{value: mintPrice}();
        tokenId2 = spnft.mint{value: mintPrice}();
        vm.stopPrank();

        vm.prank(user2);
        spnft.mint{value: mintPrice}(); // tokenId 3 to user2

        vm.label(address(spnft), "spnft");
    }

    function _simulateVRFCallback(
        uint256 requestId,
        uint256 randomness
    ) internal {
        console.log("simulating VRF callback");
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = randomness;

        vm.prank(mockVrfCoordinator);
        spnft.testFulfillRandomWords(requestId, randomWords);
    }
}

/**
 * @title SPNFTRevealEnabledTest
 * @dev Test contract for reveal-enabled state
 */
contract SPNFTRevealEnabledTest is SPNFTRevealEnabledState {
    function testRequestReveal() public {
        uint256 requestId = 123;

        // Mock the VRF call
        vm.mockCall(
            mockVrfCoordinator,
            abi.encodeWithSelector(
                VRFCoordinatorV2Interface.requestRandomWords.selector
            ),
            abi.encode(requestId)
        );

        vm.startPrank(user1);

        // Test for event emission
        vm.expectEmit(true, true, true, true);

        // Need to construct the expected tokenIds array
        uint256[] memory expectedTokenIds = new uint256[](1);
        expectedTokenIds[0] = tokenId1;

        emit SPNFT.RevealRequested(requestId, expectedTokenIds);

        // Request reveal for token1
        spnft.requestReveal(tokenId1);

        vm.stopPrank();

        // Verify the token hasn't been revealed yet (waiting for VRF callback)
        assertEq(spnft.isRevealed(tokenId1), false);
    }

    function testBatchRequestReveal() public {
        uint256 requestId = 456;

        // Mock the VRF call
        vm.mockCall(
            mockVrfCoordinator,
            abi.encodeWithSelector(
                VRFCoordinatorV2Interface.requestRandomWords.selector
            ),
            abi.encode(requestId)
        );

        vm.startPrank(deployer);

        // Prepare token IDs for batch reveal
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId1;
        tokenIds[1] = tokenId2;

        // Test for event emission
        vm.expectEmit(true, true, true, true);
        emit SPNFT.RevealRequested(requestId, tokenIds);

        // Batch request reveal
        spnft.batchRequestReveal(tokenIds);

        vm.stopPrank();

        // Verify tokens haven't been revealed yet
        assertEq(spnft.isRevealed(tokenId1), false);
        assertEq(spnft.isRevealed(tokenId2), false);
    }

    function testRequestRevealRevertsWhenNotOwner() public {
        vm.startPrank(user2);

        vm.expectRevert("Not the owner of this token");
        spnft.requestReveal(tokenId1);

        vm.stopPrank();
    }

    function testCannotSetRevealTypeAfterRevealEnabled() public {
        vm.startPrank(deployer);

        vm.expectRevert("Revealing already started");
        spnft.setRevealType(SPNFT.RevealType.SeparateCollection);

        vm.stopPrank();
    }

    function testVRFCallback() public {
        // Request reveal
        uint256 requestId = 123;

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

        // Check token is not revealed yet
        assertEq(spnft.isRevealed(tokenId1), false);

        // Simulate VRF callback
        _simulateVRFCallback(requestId, 12345);

        // Check token is now revealed
        assertEq(spnft.isRevealed(tokenId1), true);

        // Verify randomness was set
        assertEq(spnft.getRandomness(tokenId1) != 0, true);
    }
}
