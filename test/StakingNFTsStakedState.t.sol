// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// import "./StakingNFTsMintedState.t.sol";

// /**
//  * @title StakingNFTsStakedState
//  * @dev State with NFTs staked
//  */
// abstract contract StakingNFTsStakedState is StakingNFTsMintedState {
//     function setUp() public virtual override {
//         super.setUp();

//         // Stake NFTs
//         vm.startPrank(user1);

//         revealedSpnft.approve(address(staking), tokenId1);
//         staking.stake(tokenId1);

//         revealedSpnft.approve(address(staking), tokenId2);
//         staking.stake(tokenId2);

//         vm.stopPrank();

//         vm.startPrank(user2);

//         revealedSpnft.approve(address(staking), tokenId3);
//         staking.stake(tokenId3);

//         vm.stopPrank();
//     }
// }

// /**
//  * @title StakingNFTsStakedTest
//  * @dev Tests for the state with staked NFTs
//  */
// contract StakingNFTsStakedTest is StakingNFTsStakedState {
//     function testCorrectStakedTokenCount() public {
//         uint256[] memory user1Stakes = staking.getStakedTokensByOwner(user1);
//         uint256[] memory user2Stakes = staking.getStakedTokensByOwner(user2);

//         assertEq(user1Stakes.length, 2);
//         assertEq(user2Stakes.length, 1);
//     }

//     function testNoRewardsImmediatelyAfterStaking() public {
//         uint256 rewards = staking.calculateRewards(tokenId1);
//         assertEq(rewards, 0);
//     }

//     function testClaimRevertsWithNoRewards() public {
//         vm.startPrank(user1);

//         vm.expectRevert("No rewards to claim");
//         staking.claimRewards(tokenId1);

//         vm.stopPrank();
//     }

//     function testRewardAccrual() public {
//         // Fast forward 30 days
//         vm.warp(block.timestamp + 30 days);

//         // Calculate rewards
//         uint256 rewards = staking.calculateRewards(tokenId1);

//         // Rewards should be greater than 0 after 30 days
//         assertTrue(rewards > 0, "Expected rewards to accrue after 30 days");
//     }

//     function testClaimRewards() public {
//         // Fast forward 30 days
//         vm.warp(block.timestamp + 30 days);

//         // Calculate expected rewards
//         uint256 expectedRewards = staking.calculateRewards(tokenId1);

//         vm.startPrank(user1);

//         // Expect the RewardsClaimed event
//         vm.expectEmit(true, true, true, true);
//         emit SPNFTStaking.RewardsClaimed(
//             user1,
//             tokenId1,
//             expectedRewards,
//             block.timestamp
//         );

//         // Claim rewards
//         staking.claimRewards(tokenId1);

//         vm.stopPrank();

//         // Check that rewards were minted to user
//         assertEq(spToken.balanceOf(user1), expectedRewards);

//         // Check that last claim time was updated
//         (, , , uint256 lastClaimAt) = staking.stakes(tokenId1);
//         assertEq(lastClaimAt, block.timestamp);
//     }

//     function testUnstake() public {
//         // Fast forward 30 days
//         vm.warp(block.timestamp + 30 days);

//         // Calculate expected rewards
//         uint256 expectedRewards = staking.calculateRewards(tokenId1);

//         vm.startPrank(user1);

//         // Expect the NFTUnstaked event
//         vm.expectEmit(true, true, true, true);
//         emit SPNFTStaking.NFTUnstaked(user1, tokenId1, block.timestamp);

//         // Also expect the RewardsClaimed event
//         vm.expectEmit(true, true, true, true);
//         emit SPNFTStaking.RewardsClaimed(
//             user1,
//             tokenId1,
//             expectedRewards,
//             block.timestamp
//         );

//         // Unstake the NFT
//         staking.unstake(tokenId1);

//         vm.stopPrank();

//         // Check that NFT was returned to user
//         assertEq(revealedSpnft.ownerOf(tokenId1), user1);

//         // Check that rewards were minted to user
//         assertEq(spToken.balanceOf(user1), expectedRewards);

//         // Check that stake was removed
//         uint256[] memory stakedTokens = staking.getStakedTokensByOwner(user1);
//         assertEq(stakedTokens.length, 1); // Only tokenId2 remains staked

//         // Make sure the remaining token is tokenId2
//         assertEq(stakedTokens[0], tokenId2);
//     }

//     function testUnstakeRevertsWhenNotOwner() public {
//         vm.startPrank(user2);

//         // Try to unstake an NFT staked by user1
//         vm.expectRevert("You don't own this staked NFT");
//         staking.unstake(tokenId1);

//         vm.stopPrank();
//     }

//     function testClaimRevertsWhenNotOwner() public {
//         // Fast forward 30 days
//         vm.warp(block.timestamp + 30 days);

//         vm.startPrank(user2);

//         // Try to claim rewards for an NFT staked by user1
//         vm.expectRevert("You don't own this staked NFT");
//         staking.claimRewards(tokenId1);

//         vm.stopPrank();
//     }
// }
