// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// import "./SPNFTRevealEnabledState.t.sol";

// /**
//  * @title SPNFTSeparateCollectionRevealState
//  * @dev State with separate collection reveal type set and one token revealed
//  */
// abstract contract SPNFTSeparateCollectionRevealState is
//     SPNFTRevealEnabledState
// {
//     uint256 internal requestId;

//     function setUp() public virtual override {
//         super.setUp();

//         // Set reveal type to separate collection
//         vm.prank(deployer);
//         spnft.setRevealType(SPNFT.RevealType.SeparateCollection);

//         // Request reveal for token1
//         requestId = 123;

//         // Mock the VRF call
//         vm.mockCall(
//             mockVrfCoordinator,
//             abi.encodeWithSelector(
//                 VRFCoordinatorV2Interface.requestRandomWords.selector
//             ),
//             abi.encode(requestId)
//         );

//         vm.prank(user1);
//         spnft.requestReveal(tokenId1);

//         // Simulating the effects of fulfillRandomWords
//         // In a real test, you'd need a proper way to call the internal function
//         _simulateFulfillRandomWords(requestId, 12345);
//     }

//     // Helper function to simulate the effects of fulfillRandomWords
//     function _simulateFulfillRandomWords(
//         uint256 _requestId,
//         uint256 randomValue
//     ) internal virtual {
//         // In a real test, you'd implement this differently
//         // For example, you might use a test contract that exposes the internal function

//         // This is just to show the concept
//         console.log(
//             "Simulating fulfillRandomWords for requestId: %s with random value: %s",
//             _requestId,
//             randomValue
//         );
//     }
// }

// /**
//  * @title SPNFTSeparateCollectionRevealTest
//  * @dev Test contract for separate collection reveal
//  */
// contract SPNFTSeparateCollectionRevealTest is
//     SPNFTSeparateCollectionRevealState
// {
//     // These tests are simplified since we can't easily simulate fulfillRandomWords
//     // In a real implementation, you'd create a test-specific contract that exposes internal methods

//     function testRevealedCollectionAddressSet() public {
//         assertEq(spnft.revealedCollectionAddress(), address(revealedSpnft));
//     }

//     function testUnrevealedTokenStillInOriginalCollection() public {
//         // Token2 hasn't been revealed yet, so should still be in the original collection
//         assertEq(spnft.ownerOf(tokenId2), user1);
//     }
// }
