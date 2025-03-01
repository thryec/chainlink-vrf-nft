// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// import "./StakingDeployedState.t.sol";

// /**
//  * @title StakingNFTsMintedState
//  * @dev State with NFTs minted and ready to be staked
//  */
// abstract contract StakingNFTsMintedState is StakingDeployedState {
//     uint256 internal tokenId1;
//     uint256 internal tokenId2;
//     uint256 internal tokenId3;

//     function setUp() public virtual override {
//         super.setUp();

//         vm.startPrank(deployer);

//         // Mint NFTs to users
//         tokenId1 = 1;
//         tokenId2 = 2;
//         tokenId3 = 3;

//         revealedSpnft.mintRevealed(user1, tokenId1, 12345);
//         revealedSpnft.mintRevealed(user1, tokenId2, 54321);
//         revealedSpnft.mintRevealed(user2, tokenId3, 98765);

//         vm.stopPrank();
//     }
// }

// /**
//  * @title StakingNFTsMintedTest
//  * @dev Tests for the state with NFTs minted and ready to be staked
//  */
// contract StakingNFTsMintedTest is StakingNFTsMintedState {
//     function testNFTsCorrectlyMinted() public {
//         assertEq(revealedSpnft.ownerOf(tokenId1), user1);
//         assertEq(revealedSpnft.ownerOf(tokenId2), user1);
//         assertEq(revealedSpnft.ownerOf(tokenId3), user2);

//         assertEq(revealedSpnft.balanceOf(user1), 2);
//         assertEq(revealedSpnft.balanceOf(user2), 1);
//     }

//     function testStake() public {
//         vm.startPrank(user1);

//         // Approve and stake the first NFT
//         revealedSpnft.approve(address(staking), tokenId1);
//         staking.stake(tokenId1);

//         vm.stopPrank();

//         // Check ownership transferred to staking contract
//         assertEq(revealedSpnft.ownerOf(tokenId1), address(staking));

//         // Check stake details
//         (
//             address owner,
//             uint256 tokenId,
//             uint256 stakedAt,
//             uint256 lastClaimAt
//         ) = staking.stakes(tokenId1);
//         assertEq(owner, user1);
//         assertEq(tokenId, tokenId1);
//         assertEq(stakedAt, block.timestamp);
//         assertEq(lastClaimAt, block.timestamp);

//         // Check staked tokens list
//         uint256[] memory stakedTokens = staking.getStakedTokensByOwner(user1);
//         assertEq(stakedTokens.length, 1);
//         assertEq(stakedTokens[0], tokenId1);
//     }

//     function testStakeEmitsEvent() public {
//         vm.startPrank(user1);

//         // Approve the NFT for staking
//         revealedSpnft.approve(address(staking), tokenId1);

//         // Expect the NFTStaked event to be emitted
//         vm.expectEmit(true, true, true, true);
//         emit SPNFTStaking.NFTStaked(user1, tokenId1, block.timestamp);

//         // Stake the NFT
//         staking.stake(tokenId1);

//         vm.stopPrank();
//     }

//     function testStakeRevertsWhenNotOwner() public {
//         vm.startPrank(user2);

//         // Try to stake an NFT owned by user1
//         vm.expectRevert("You don't own this NFT");
//         staking.stake(tokenId1);

//         vm.stopPrank();
//     }
// }
