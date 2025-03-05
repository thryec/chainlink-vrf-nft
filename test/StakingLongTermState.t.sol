// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23;

import "./StakingNFTsStakedState.t.sol";

/**
 * @title StakingLongTermState
 * @dev State with NFTs staked for a long period (1 year)
 */
abstract contract StakingLongTermState is StakingNFTsStakedState {
    function setUp() public virtual override {
        super.setUp();

        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);
    }
}

/**
 * @title StakingLongTermTest
 * @dev Tests for long-term staking behavior and accurate APY
 */
contract StakingLongTermTest is StakingLongTermState {
    function testOneYearRewardsMatchAPY() public {
        // Calculate rewards after 1 year for both token types
        uint256 originalRewards = staking.calculateRewards(
            SPNFTStaking.NFTType.Original,
            originalTokenId1
        );
        uint256 revealedRewards = staking.calculateRewards(
            SPNFTStaking.NFTType.Revealed,
            revealedTokenId1
        );

        // One year of 5% APY on 1 ether (the base reward amount)
        uint256 expectedRewards = (1 ether * 5) / 100; // 5% of 1 ether

        // Check original collection rewards
        uint256 originalDifference = originalRewards > expectedRewards
            ? originalRewards - expectedRewards
            : expectedRewards - originalRewards;

        // Check revealed collection rewards
        uint256 revealedDifference = revealedRewards > expectedRewards
            ? revealedRewards - expectedRewards
            : expectedRewards - revealedRewards;

        // Difference should be minimal (less than 0.0001 ether)
        assertTrue(
            originalDifference < 1e14,
            "Original collection APY calculation should be close to 5%"
        );
        assertTrue(
            revealedDifference < 1e14,
            "Revealed collection APY calculation should be close to 5%"
        );

        // Both collections should have roughly the same rewards
        uint256 collectionsDifference = originalRewards > revealedRewards
            ? originalRewards - revealedRewards
            : revealedRewards - originalRewards;

        assertTrue(
            collectionsDifference < 1e12,
            "Both collections should have equal APY"
        );
    }

    function testTotalPendingRewards() public {
        // Get total pending rewards for user1 (who has 4 staked tokens, 2 from each collection)
        uint256 totalRewards = staking.getTotalPendingRewards(user1);

        // Each token should have accrued approximately 0.05 ether (5% of 1 ether)
        // So the total should be approximately 0.2 ether (4 tokens)
        uint256 expectedTotal = (1 ether * 5 * 4) / 100; // 5% of 1 ether × 4 tokens

        // Allow for small rounding differences
        uint256 difference = totalRewards > expectedTotal
            ? totalRewards - expectedTotal
            : expectedTotal - totalRewards;

        assertTrue(
            difference < 1e14,
            "Total rewards calculation should be close to 4 * 5%"
        );
    }

    // function testMultipleClaimsOverTime() public {
    //     vm.startPrank(user1);

    //     // First claim rewards for originalTokenId1
    //     uint256 originalFirstClaimAmount = staking.calculateRewards(
    //         SPNFTStaking.NFTType.Original,
    //         originalTokenId1
    //     );
    //     staking.claimRewards(SPNFTStaking.NFTType.Original, originalTokenId1);

    //     // First claim rewards for revealedTokenId1
    //     uint256 revealedFirstClaimAmount = staking.calculateRewards(
    //         SPNFTStaking.NFTType.Revealed,
    //         revealedTokenId1
    //     );
    //     staking.claimRewards(SPNFTStaking.NFTType.Revealed, revealedTokenId1);

    //     // Fast forward another 6 months
    //     vm.warp(block.timestamp + 182 days);

    //     // Claim rewards again for both token types
    //     uint256 originalSecondClaimAmount = staking.calculateRewards(
    //         SPNFTStaking.NFTType.Original,
    //         originalTokenId1
    //     );
    //     staking.claimRewards(SPNFTStaking.NFTType.Original, originalTokenId1);

    //     uint256 revealedSecondClaimAmount = staking.calculateRewards(
    //         SPNFTStaking.NFTType.Revealed,
    //         revealedTokenId1
    //     );
    //     staking.claimRewards(SPNFTStaking.NFTType.Revealed, revealedTokenId1);

    //     vm.stopPrank();

    //     // Second claims should be approximately half of the first claims
    //     // (since they're for 6 months instead of 12)
    //     uint256 expectedOriginalRatio = originalFirstClaimAmount / 2;
    //     uint256 expectedRevealedRatio = revealedFirstClaimAmount / 2;
    //     uint256 tolerance = 1e13; // Allow for some variance due to day counting

    //     assertTrue(
    //         originalSecondClaimAmount >= expectedOriginalRatio - tolerance &&
    //             originalSecondClaimAmount <= expectedOriginalRatio + tolerance,
    //         "Original collection second claim should be approximately half of the first claim"
    //     );

    //     assertTrue(
    //         revealedSecondClaimAmount >= expectedRevealedRatio - tolerance &&
    //             revealedSecondClaimAmount <= expectedRevealedRatio + tolerance,
    //         "Revealed collection second claim should be approximately half of the first claim"
    //     );

    //     // Total rewards should be approximately 15% of 1 ether (5% for year 1 + 2.5% for half of year 2) × 2 tokens
    //     uint256 totalRewards = spToken.balanceOf(user1);
    //     uint256 expectedTotal = (1 ether * 75 * 2) / 1000; // 7.5% of 1 ether × 2 tokens

    //     uint256 difference = totalRewards > expectedTotal
    //         ? totalRewards - expectedTotal
    //         : expectedTotal - totalRewards;

    //     assertTrue(
    //         difference < 1e14,
    //         "Total claimed rewards should be close to 7.5% * 2"
    //     );
    // }

    // function testRoundTripStakingFlow() public {
    //     // Test a complete flow for one token of each type:
    //     // 1. Unstake after 1 year
    //     // 2. Re-stake
    //     // 3. Unstake again after another 6 months

    //     vm.startPrank(user1);

    //     // 1. Unstake after 1 year (current state)
    //     uint256 originalRewards1 = staking.calculateRewards(
    //         SPNFTStaking.NFTType.Original,
    //         originalTokenId1
    //     );
    //     staking.unstake(SPNFTStaking.NFTType.Original, originalTokenId1);

    //     uint256 revealedRewards1 = staking.calculateRewards(
    //         SPNFTStaking.NFTType.Revealed,
    //         revealedTokenId1
    //     );
    //     staking.unstake(SPNFTStaking.NFTType.Revealed, revealedTokenId1);

    //     // 2. Re-stake both NFTs
    //     spnftWithVRF.approve(address(staking), originalTokenId1);
    //     staking.stake(SPNFTStaking.NFTType.Original, originalTokenId1);

    //     revealedSpnft.approve(address(staking), revealedTokenId1);
    //     staking.stake(SPNFTStaking.NFTType.Revealed, revealedTokenId1);

    //     // 3. Fast forward 6 months
    //     vm.warp(block.timestamp + 182 days);

    //     // 4. Unstake again
    //     uint256 originalRewards2 = staking.calculateRewards(
    //         SPNFTStaking.NFTType.Original,
    //         originalTokenId1
    //     );
    //     staking.unstake(SPNFTStaking.NFTType.Original, originalTokenId1);

    //     uint256 revealedRewards2 = staking.calculateRewards(
    //         SPNFTStaking.NFTType.Revealed,
    //         revealedTokenId1
    //     );
    //     staking.unstake(SPNFTStaking.NFTType.Revealed, revealedTokenId1);

    //     vm.stopPrank();

    //     // Second rewards should be approximately 2.5% (half of 5%)
    //     uint256 expectedHalfYearReward = (1 ether * 5) / 200; // 2.5% of 1 ether

    //     assertApproxEqAbs(originalRewards2, expectedHalfYearReward, 1e13);
    //     assertApproxEqAbs(revealedRewards2, expectedHalfYearReward, 1e13);

    //     // Total rewards should be 7.5% (5% + 2.5%) of 1 ether × 2 tokens
    //     uint256 totalRewards = spToken.balanceOf(user1);
    //     uint256 expectedTotal = (1 ether * 75 * 2) / 1000; // 7.5% of 1 ether × 2 tokens

    //     assertApproxEqAbs(totalRewards, expectedTotal, 1e13);
    // }
}
