// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./SPNFTMintedState.t.sol";

/**
 * @title SPNFTRevealEnabledState
 * @dev State with SPNFT tokens minted and revealing enabled but tokens not yet revealed
 */
abstract contract SPNFTRevealEnabledState is SPNFTMintedState {
    function setUp() public virtual override {
        super.setUp();

        // Enable revealing
        vm.prank(deployer);
        spnft.setRevealEnabled(true);
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
}
