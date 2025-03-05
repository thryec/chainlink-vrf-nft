// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23;

import "./StakingNFTsMintedState.t.sol";

/**
 * @title StakingNFTsStakedState
 * @dev State with both types of NFTs staked
 */
abstract contract StakingNFTsStakedState is StakingNFTsMintedState {
    function setUp() public virtual override {
        super.setUp();

        // Stake NFTs from original collection
        vm.startPrank(user1);

        spnftWithVRF.approve(address(staking), originalTokenId1);
        staking.stake(SPNFTStaking.NFTType.Original, originalTokenId1);

        spnftWithVRF.approve(address(staking), originalTokenId2);
        staking.stake(SPNFTStaking.NFTType.Original, originalTokenId2);

        // Stake NFTs from revealed collection
        revealedSpnft.approve(address(staking), revealedTokenId1);
        staking.stake(SPNFTStaking.NFTType.Revealed, revealedTokenId1);

        revealedSpnft.approve(address(staking), revealedTokenId2);
        staking.stake(SPNFTStaking.NFTType.Revealed, revealedTokenId2);

        vm.stopPrank();
    }
}

/**
 * @title StakingNFTsStakedTest
 * @dev Tests for the state with staked NFTs
 */
contract StakingNFTsStakedTest is StakingNFTsStakedState {
    function testCorrectStakedTokenCount() public {
        uint256[] memory originalTokens;
        uint256[] memory revealedTokens;
        (originalTokens, revealedTokens) = staking.getAllStakedTokens(user1);

        assertEq(originalTokens.length, 2);
        assertEq(revealedTokens.length, 2);
        assertEq(staking.getTotalStakedByOwner(user1), 4);
    }

    function testNoRewardsImmediatelyAfterStaking() public {
        uint256 originalRewards = staking.calculateRewards(
            SPNFTStaking.NFTType.Original,
            originalTokenId1
        );
        uint256 revealedRewards = staking.calculateRewards(
            SPNFTStaking.NFTType.Revealed,
            revealedTokenId1
        );

        assertEq(originalRewards, 0);
        assertEq(revealedRewards, 0);
    }

    function testClaimRevertsWithNoRewards() public {
        vm.startPrank(user1);

        vm.expectRevert("No rewards to claim");
        staking.claimRewards(SPNFTStaking.NFTType.Original, originalTokenId1);

        vm.expectRevert("No rewards to claim");
        staking.claimRewards(SPNFTStaking.NFTType.Revealed, revealedTokenId1);

        vm.stopPrank();
    }

    function testRewardAccrual() public {
        // Fast forward 30 days
        vm.warp(block.timestamp + 30 days);

        // Calculate rewards for both types
        uint256 originalRewards = staking.calculateRewards(
            SPNFTStaking.NFTType.Original,
            originalTokenId1
        );
        uint256 revealedRewards = staking.calculateRewards(
            SPNFTStaking.NFTType.Revealed,
            revealedTokenId1
        );

        // Rewards should be greater than 0 after 30 days
        assertTrue(
            originalRewards > 0,
            "Expected original collection rewards to accrue after 30 days"
        );
        assertTrue(
            revealedRewards > 0,
            "Expected revealed collection rewards to accrue after 30 days"
        );

        // Both reward types should be roughly the same (since they use the same APY)
        uint256 difference = originalRewards > revealedRewards
            ? originalRewards - revealedRewards
            : revealedRewards - originalRewards;

        assertTrue(
            difference < 1e10,
            "Rewards should be roughly equal for both token types"
        );
    }

    function testClaimRewards() public {
        // Fast forward 30 days
        vm.warp(block.timestamp + 30 days);

        // Calculate expected rewards
        uint256 expectedRewards = staking.calculateRewards(
            SPNFTStaking.NFTType.Original,
            originalTokenId1
        );

        vm.startPrank(user1);

        // Expect the RewardsClaimed event
        vm.expectEmit(true, true, true, true);
        emit SPNFTStaking.RewardsClaimed(
            user1,
            originalTokenId1,
            SPNFTStaking.NFTType.Original,
            expectedRewards,
            block.timestamp
        );

        // Claim rewards
        staking.claimRewards(SPNFTStaking.NFTType.Original, originalTokenId1);

        vm.stopPrank();

        // Check that rewards were minted to user
        assertEq(spToken.balanceOf(user1), expectedRewards);
    }

    function testUnstake() public {
        // Fast forward 30 days
        vm.warp(block.timestamp + 30 days);

        // Calculate expected rewards
        uint256 expectedRewards = staking.calculateRewards(
            SPNFTStaking.NFTType.Original,
            originalTokenId1
        );

        vm.startPrank(user1);

        // Also expect the RewardsClaimed event
        vm.expectEmit(true, true, true, true);
        emit SPNFTStaking.RewardsClaimed(
            user1,
            originalTokenId1,
            SPNFTStaking.NFTType.Original,
            expectedRewards,
            block.timestamp
        );

        // Expect the NFTUnstaked event
        vm.expectEmit(true, true, true, true);
        emit SPNFTStaking.NFTUnstaked(
            user1,
            originalTokenId1,
            SPNFTStaking.NFTType.Original,
            block.timestamp
        );

        // Unstake the NFT
        staking.unstake(SPNFTStaking.NFTType.Original, originalTokenId1);

        vm.stopPrank();

        // Check that NFT was returned to user
        assertEq(spnftWithVRF.ownerOf(originalTokenId1), user1);

        // Check that rewards were minted to user
        assertEq(spToken.balanceOf(user1), expectedRewards);

        // Check that stake was removed
        uint256[] memory originalTokens;
        uint256[] memory revealedTokens;
        (originalTokens, revealedTokens) = staking.getAllStakedTokens(user1);

        assertEq(originalTokens.length, 1); // Only originalTokenId2 remains staked
        assertEq(revealedTokens.length, 2); // Both revealed tokens remain staked

        // Make sure the remaining original token is originalTokenId2
        assertEq(originalTokens[0], originalTokenId2);
    }

    function testUnstakeBothCollections() public {
        // Fast forward 30 days
        vm.warp(block.timestamp + 30 days);

        vm.startPrank(user1);

        // Unstake one from each collection
        staking.unstake(SPNFTStaking.NFTType.Original, originalTokenId1);
        staking.unstake(SPNFTStaking.NFTType.Revealed, revealedTokenId1);

        vm.stopPrank();

        // Check that NFTs were returned to user
        assertEq(spnftWithVRF.ownerOf(originalTokenId1), user1);
        assertEq(revealedSpnft.ownerOf(revealedTokenId1), user1);

        // Check that stakes were removed
        uint256[] memory originalTokens;
        uint256[] memory revealedTokens;
        (originalTokens, revealedTokens) = staking.getAllStakedTokens(user1);

        assertEq(originalTokens.length, 1);
        assertEq(revealedTokens.length, 1);
        assertEq(staking.getTotalStakedByOwner(user1), 2);
    }

    function testTotalPendingRewards() public {
        // Fast forward 30 days
        vm.warp(block.timestamp + 30 days);

        // Calculate individual rewards
        uint256 originalReward1 = staking.calculateRewards(
            SPNFTStaking.NFTType.Original,
            originalTokenId1
        );
        uint256 originalReward2 = staking.calculateRewards(
            SPNFTStaking.NFTType.Original,
            originalTokenId2
        );
        uint256 revealedReward1 = staking.calculateRewards(
            SPNFTStaking.NFTType.Revealed,
            revealedTokenId1
        );
        uint256 revealedReward2 = staking.calculateRewards(
            SPNFTStaking.NFTType.Revealed,
            revealedTokenId2
        );

        // Calculate total
        uint256 expectedTotal = originalReward1 +
            originalReward2 +
            revealedReward1 +
            revealedReward2;

        // Get total from contract
        uint256 totalRewards = staking.getTotalPendingRewards(user1);

        // Should be approximately equal
        assertApproxEqAbs(totalRewards, expectedTotal, 10);
    }

    function testUnstakeRevertsWhenNotOwner() public {
        vm.startPrank(user2);

        // Try to unstake an NFT staked by user1
        vm.expectRevert("You don't own this staked NFT");
        staking.unstake(SPNFTStaking.NFTType.Original, originalTokenId1);

        vm.expectRevert("You don't own this staked NFT");
        staking.unstake(SPNFTStaking.NFTType.Revealed, revealedTokenId1);

        vm.stopPrank();
    }

    function testClaimRevertsWhenNotOwner() public {
        // Fast forward 30 days
        vm.warp(block.timestamp + 30 days);

        vm.startPrank(user2);

        // Try to claim rewards for an NFT staked by user1
        vm.expectRevert("You don't own this staked NFT");
        staking.claimRewards(SPNFTStaking.NFTType.Original, originalTokenId1);

        vm.expectRevert("You don't own this staked NFT");
        staking.claimRewards(SPNFTStaking.NFTType.Revealed, revealedTokenId1);

        vm.stopPrank();
    }
}
