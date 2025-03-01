// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.19;

// import "./StakingNFTsStakedState.t.sol";

// /**
//  * @title StakingLongTermState
//  * @dev State with NFTs staked for a long period (1 year)
//  */
// abstract contract StakingLongTermState is StakingNFTsStakedState {
//     function setUp() public virtual override {
//         super.setUp();

//         // Fast forward 1 year
//         vm.warp(block.timestamp + 365 days);
//     }
// }

// /**
//  * @title StakingLongTermTest
//  * @dev Tests for long-term staking behavior and accurate APY
//  */
// contract StakingLongTermTest is StakingLongTermState {
//     function testOneYearRewardsMatchAPY() public {
//         // Calculate rewards after 1 year
//         uint256 rewards = staking.calculateRewards(tokenId1);

//         // One year of 5% APY on 1 ether (the base reward amount)
//         uint256 expectedRewards = (1 ether * 5) / 100; // 5% of 1 ether

//         // Allow for small rounding differences due to block time precision
//         uint256 difference = rewards > expectedRewards
//             ? rewards - expectedRewards
//             : expectedRewards - rewards;

//         // Difference should be minimal (less than 0.0001 ether)
//         assertTrue(difference < 1e14, "APY calculation should be close to 5%");
//     }

//     function testTotalPendingRewards() public {
//         // Get total pending rewards for user1 (who has 2 staked tokens)
//         uint256 totalRewards = staking.getTotalPendingRewards(user1);

//         // Each token should have accrued approximately 0.05 ether (5% of 1 ether)
//         // So the total should be approximately 0.1 ether
//         uint256 expectedTotal = (1 ether * 5 * 2) / 100; // 5% of 1 ether × 2 tokens

//         // Allow for small rounding differences
//         uint256 difference = totalRewards > expectedTotal
//             ? totalRewards - expectedTotal
//             : expectedTotal - totalRewards;

//         assertTrue(
//             difference < 2e14,
//             "Total rewards calculation should be close to 2 times 5%"
//         );
//     }

//     function testMultipleClaimsOverTime() public {
//         vm.startPrank(user1);

//         // First claim rewards for tokenId1
//         uint256 firstClaimAmount = staking.calculateRewards(tokenId1);
//         staking.claimRewards(tokenId1);

//         // Fast forward another 6 months
//         vm.warp(block.timestamp + 182 days);

//         // Claim rewards again
//         uint256 secondClaimAmount = staking.calculateRewards(tokenId1);
//         staking.claimRewards(tokenId1);

//         vm.stopPrank();

//         // Second claim should be approximately half of the first claim
//         // (since it's for 6 months instead of 12)
//         uint256 expectedRatio = firstClaimAmount / 2;
//         uint256 tolerance = 1e13; // Allow for some variance due to day counting

//         assertTrue(
//             secondClaimAmount >= expectedRatio - tolerance &&
//                 secondClaimAmount <= expectedRatio + tolerance,
//             "Second claim should be approximately half of the first claim"
//         );

//         // Total rewards should be approximately 7.5% of 1 ether (5% for year 1 + 2.5% for half of year 2)
//         uint256 totalRewards = spToken.balanceOf(user1);
//         uint256 expectedTotal = (1 ether * 75) / 1000; // 7.5% of 1 ether

//         uint256 difference = totalRewards > expectedTotal
//             ? totalRewards - expectedTotal
//             : expectedTotal - totalRewards;

//         assertTrue(
//             difference < 2e14,
//             "Total claimed rewards should be close to 7.5%"
//         );
//     }
// }
