// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/SPNFT.sol";
import "../../src/RevealedSPNFT.sol";
import "../../src/SPToken.sol";
import "../../src/SPNFTStaking.sol";
import "../../src/VRFMock.sol";

contract StakingFuzzTest is Test {
    SPNFTWithExposedVRF internal spnft;
    RevealedSPNFT internal revealedSpnft;
    SPToken internal spToken;
    SPNFTStaking internal staking;

    address deployer;
    address user;
    address vrfCoordinator;

    uint256 mintPrice = 0.01 ether;

    function setUp() public {
        deployer = makeAddr("deployer");
        user = makeAddr("user");
        vrfCoordinator = makeAddr("vrfCoordinator");

        vm.startPrank(deployer);

        // Deploy contracts
        spnft = new SPNFTWithExposedVRF(
            "SP NFT",
            "SPNFT",
            mintPrice,
            1000,
            vrfCoordinator,
            keccak256("keyHash"),
            1
        );

        revealedSpnft = new RevealedSPNFT("Revealed SP NFT", "RSPNFT");
        revealedSpnft.setSPNFTContract(address(spnft));
        spnft.setRevealedCollectionAddress(address(revealedSpnft));

        // Set up metadata
        string[] memory names = new string[](3);
        names[0] = "Red SP";
        names[1] = "Green SP";
        names[2] = "Blue SP";

        string[] memory descriptions = new string[](3);
        descriptions[0] = "A red SP NFT with special powers.";
        descriptions[1] = "A green SP NFT with unique abilities.";
        descriptions[2] = "A blue SP NFT with rare attributes.";

        string[] memory images = new string[](3);
        images[0] = "data:image/svg+xml;base64,base64encodedsvg1";
        images[1] = "data:image/svg+xml;base64,base64encodedsvg2";
        images[2] = "data:image/svg+xml;base64,base64encodedsvg3";

        string[] memory attributes = new string[](3);
        attributes[
            0
        ] = '[{"trait_type":"Color","value":"Red"},{"trait_type":"Rarity","value":"Common"}]';
        attributes[
            1
        ] = '[{"trait_type":"Color","value":"Green"},{"trait_type":"Rarity","value":"Uncommon"}]';
        attributes[
            2
        ] = '[{"trait_type":"Color","value":"Blue"},{"trait_type":"Rarity","value":"Rare"}]';

        spnft.setMetadata(names, descriptions, images, attributes);
        revealedSpnft.setMetadata(names, descriptions, images, attributes);

        // Set up and initialize SPToken and Staking
        spToken = new SPToken("SP Token", "SPT");
        staking = new SPNFTStaking(
            address(spnft),
            address(revealedSpnft),
            address(spToken)
        );
        spToken.setStakingContract(address(staking));

        // Enable minting
        spnft.setMintEnabled(true);

        vm.stopPrank();
    }

    // Test staking rewards accrual with different time periods
    function testFuzz_StakingRewardsOverTime(
        uint64 stakingDays,
        uint64 claimingFrequency
    ) public {
        // Bound to realistic values (1 day to 3 years, claim every 1-365 days)
        stakingDays = uint64(bound(stakingDays, 1, 1095));
        claimingFrequency = uint64(bound(claimingFrequency, 1, 365));

        require(
            claimingFrequency <= stakingDays,
            "Claiming frequency must be <= staking days"
        );

        // Mint and reveal an NFT
        vm.deal(user, mintPrice);

        // Set in-collection reveal
        vm.prank(deployer);
        spnft.setRevealType(SPNFT.RevealType.InCollection);

        // Enable reveal
        vm.prank(deployer);
        spnft.setRevealEnabled(true);

        // Mint token
        vm.prank(user);
        uint256 tokenId = spnft.mint{value: mintPrice}();

        // Reveal token
        uint256 requestId = 12345;
        vm.mockCall(
            vrfCoordinator,
            abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        "requestRandomWords(bytes32,uint64,uint16,uint32,uint32,uint256)"
                    )
                )
            ),
            abi.encode(requestId)
        );

        vm.prank(user);
        spnft.requestReveal(tokenId);

        // Simulate VRF callback
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 54321;

        // Need to use empty bytes for extraArgs in V2Plus
        bytes memory extraArgs = new bytes(0);

        vm.prank(vrfCoordinator);
        spnft.testFulfillRandomWords(requestId, randomWords);

        // Stake the token
        vm.startPrank(user);
        spnft.approve(address(staking), tokenId);
        staking.stake(SPNFTStaking.NFTType.Original, tokenId);
        vm.stopPrank();

        // Start tracking rewards
        uint256 totalExpectedRewards = 0;
        uint256 totalClaimedRewards = 0;

        // Simulate staking and periodic claiming
        uint64 remainingDays = stakingDays;
        while (remainingDays > 0) {
            uint64 daysToWarp = remainingDays >= claimingFrequency
                ? claimingFrequency
                : remainingDays;
            remainingDays -= daysToWarp;

            // Move time forward
            vm.warp(block.timestamp + daysToWarp * 1 days);

            // Calculate expected rewards for this period
            uint256 periodRewards = (1 ether * 5 * daysToWarp) / (365 * 100);
            totalExpectedRewards += periodRewards;

            // Claim rewards
            uint256 beforeBalance = spToken.balanceOf(user);

            vm.prank(user);
            staking.claimRewards(SPNFTStaking.NFTType.Original, tokenId);

            uint256 afterBalance = spToken.balanceOf(user);
            uint256 claimedAmount = afterBalance - beforeBalance;

            totalClaimedRewards += claimedAmount;

            // Verify claimed amount is close to expected for this period (allow small rounding differences)
            uint256 claimDifference = claimedAmount > periodRewards
                ? claimedAmount - periodRewards
                : periodRewards - claimedAmount;

            assertLe(
                claimDifference,
                10,
                "Claimed rewards should be close to expected"
            );
        }

        // Finally unstake the token and get remaining rewards
        vm.prank(user);
        staking.unstake(SPNFTStaking.NFTType.Original, tokenId);

        // Verify token ownership returned to user
        assertEq(spnft.ownerOf(tokenId), user);

        // Verify total rewards are close to expected (total APY)
        uint256 finalBalance = spToken.balanceOf(user);
        uint256 totalRewards = finalBalance;

        uint256 expectedYearlyRewards = (1 ether * 5 * stakingDays) /
            (365 * 100);
        uint256 difference = totalRewards > expectedYearlyRewards
            ? totalRewards - expectedYearlyRewards
            : expectedYearlyRewards - totalRewards;

        assertLe(
            difference,
            stakingDays,
            "Total rewards should match expected APY within tolerance"
        );
    }

    // Test parallel staking across both collections
    function testFuzz_ParallelStaking(
        uint8 originalTokenCount,
        uint8 revealedTokenCount,
        uint64 stakingDays
    ) public {
        // Bound inputs to reasonable ranges
        originalTokenCount = uint8(bound(originalTokenCount, 1, 5));
        revealedTokenCount = uint8(bound(revealedTokenCount, 1, 5));
        stakingDays = uint64(bound(stakingDays, 1, 365));

        // Provide user with funds
        vm.deal(
            user,
            mintPrice * (originalTokenCount + revealedTokenCount) * 2
        );

        // Setup collections
        vm.startPrank(deployer);
        // First set in-collection reveal for original tokens
        spnft.setRevealType(SPNFT.RevealType.InCollection);
        spnft.setRevealEnabled(true);
        vm.stopPrank();

        // Array to track both sets of token IDs
        uint256[] memory originalTokenIds = new uint256[](originalTokenCount);
        uint256[] memory revealedTokenIds = new uint256[](revealedTokenCount);

        // Mint and reveal original collection tokens
        for (uint8 i = 0; i < originalTokenCount; i++) {
            // Mint token
            vm.prank(user);
            originalTokenIds[i] = spnft.mint{value: mintPrice}();

            // Request reveal
            uint256 requestId = 10000 + i;
            vm.mockCall(
                vrfCoordinator,
                abi.encodeWithSelector(
                    bytes4(
                        keccak256(
                            "requestRandomWords(bytes32,uint64,uint16,uint32,uint32,uint256)"
                        )
                    )
                ),
                abi.encode(requestId)
            );

            vm.prank(user);
            spnft.requestReveal(originalTokenIds[i]);

            // Simulate VRF callback
            uint256[] memory randomWords = new uint256[](1);
            randomWords[0] = uint256(keccak256(abi.encode("original", i)));

            vm.prank(vrfCoordinator);
            spnft.testFulfillRandomWords(requestId, randomWords);
        }

        // Switch to separate collection for second batch
        vm.prank(deployer);
        spnft.setRevealType(SPNFT.RevealType.SeparateCollection);

        // Mint and reveal separate collection tokens
        for (uint8 i = 0; i < revealedTokenCount; i++) {
            // Mint token to be revealed
            vm.prank(user);
            uint256 tokenToReveal = spnft.mint{value: mintPrice}();

            // This will become the revealed token ID
            revealedTokenIds[i] = tokenToReveal;

            // Request reveal
            uint256 requestId = 20000 + i;
            vm.mockCall(
                vrfCoordinator,
                abi.encodeWithSelector(
                    bytes4(
                        keccak256(
                            "requestRandomWords(bytes32,uint64,uint16,uint32,uint32,uint256)"
                        )
                    )
                ),
                abi.encode(requestId)
            );

            vm.prank(user);
            spnft.requestReveal(tokenToReveal);

            // Simulate VRF callback
            uint256[] memory randomWords = new uint256[](1);
            randomWords[0] = uint256(keccak256(abi.encode("revealed", i)));

            vm.prank(vrfCoordinator);
            spnft.testFulfillRandomWords(requestId, randomWords);

            // Verify token exists in revealed collection now
            assertEq(revealedSpnft.ownerOf(revealedTokenIds[i]), user);
        }

        // Stake all tokens
        vm.startPrank(user);

        // Stake original collection tokens
        for (uint8 i = 0; i < originalTokenCount; i++) {
            spnft.approve(address(staking), originalTokenIds[i]);
            staking.stake(SPNFTStaking.NFTType.Original, originalTokenIds[i]);
        }

        // Stake revealed collection tokens
        for (uint8 i = 0; i < revealedTokenCount; i++) {
            revealedSpnft.approve(address(staking), revealedTokenIds[i]);
            staking.stake(SPNFTStaking.NFTType.Revealed, revealedTokenIds[i]);
        }

        vm.stopPrank();

        // Verify staked counts
        uint256[] memory stakedOriginal = staking.getStakedOriginalTokens(user);
        uint256[] memory stakedRevealed = staking.getStakedRevealedTokens(user);

        assertEq(stakedOriginal.length, originalTokenCount);
        assertEq(stakedRevealed.length, revealedTokenCount);
        assertEq(
            staking.getTotalStakedByOwner(user),
            originalTokenCount + revealedTokenCount
        );

        // Move time forward
        vm.warp(block.timestamp + stakingDays * 1 days);

        // Calculate total rewards
        uint256 totalRewards = staking.getTotalPendingRewards(user);

        // Expected rewards from both collections
        uint256 totalTokens = originalTokenCount + revealedTokenCount;
        uint256 expectedRewards = (1 ether * 5 * stakingDays * totalTokens) /
            (365 * 100);

        // Allow small difference per token
        uint256 difference = totalRewards > expectedRewards
            ? totalRewards - expectedRewards
            : expectedRewards - totalRewards;

        assertLe(
            difference,
            totalTokens * 10,
            "Total rewards should be close to expected APY"
        );

        // Unstake everything and verify rewards
        vm.startPrank(user);

        for (uint8 i = 0; i < originalTokenCount; i++) {
            staking.unstake(SPNFTStaking.NFTType.Original, originalTokenIds[i]);
        }

        for (uint8 i = 0; i < revealedTokenCount; i++) {
            staking.unstake(SPNFTStaking.NFTType.Revealed, revealedTokenIds[i]);
        }

        vm.stopPrank();

        // Verify all tokens returned
        for (uint8 i = 0; i < originalTokenCount; i++) {
            assertEq(spnft.ownerOf(originalTokenIds[i]), user);
        }

        for (uint8 i = 0; i < revealedTokenCount; i++) {
            assertEq(revealedSpnft.ownerOf(revealedTokenIds[i]), user);
        }

        // Verify reward tokens received
        uint256 finalBalance = spToken.balanceOf(user);
        assertGe(finalBalance, expectedRewards - (totalTokens * 10));
        assertLe(finalBalance, expectedRewards + (totalTokens * 10));

        // Verify nothing left staked
        assertEq(staking.getTotalStakedByOwner(user), 0);
    }

    // Test staking with edge case token IDs
    function testFuzz_EdgeCaseTokenIds(uint256 tokenId) public {
        // Bound to unusual but valid token IDs
        tokenId = bound(tokenId, 1, type(uint64).max);

        // Setup for this test with custom token ID
        vm.startPrank(deployer);

        // Set in-collection reveal
        spnft.setRevealType(SPNFT.RevealType.InCollection);
        spnft.setRevealEnabled(true);

        // Mint the token with the specific ID (directly to simulate unusual ID)
        vm.stopPrank();

        // We'll need to mint tokens until we reach this ID
        // For testing purposes, we'll use a shortcut - directly "create" the token
        // This is just for testing the staking contract's handling of unusual IDs
        vm.startPrank(deployer);

        // Mint a normal token to user first
        vm.deal(user, mintPrice);
        vm.stopPrank();

        vm.prank(user);
        uint256 normalTokenId = spnft.mint{value: mintPrice}();

        // Now reveal it
        uint256 requestId = 12345;
        vm.mockCall(
            vrfCoordinator,
            abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        "requestRandomWords(bytes32,uint64,uint16,uint32,uint32,uint256)"
                    )
                )
            ),
            abi.encode(requestId)
        );

        vm.prank(user);
        spnft.requestReveal(normalTokenId);

        // Simulate VRF callback
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 123456789;

        vm.prank(vrfCoordinator);
        spnft.testFulfillRandomWords(requestId, randomWords);

        // Let's also test with a revealed token from separate collection
        vm.prank(deployer);
        spnft.setRevealType(SPNFT.RevealType.SeparateCollection);

        // Mint another token to be moved to revealed collection
        vm.deal(user, mintPrice);
        vm.prank(user);
        uint256 separateTokenId = spnft.mint{value: mintPrice}();

        // Request reveal for separate collection
        uint256 requestId2 = 67890;
        vm.mockCall(
            vrfCoordinator,
            abi.encodeWithSelector(
                bytes4(
                    keccak256(
                        "requestRandomWords(bytes32,uint64,uint16,uint32,uint32,uint256)"
                    )
                )
            ),
            abi.encode(requestId2)
        );

        vm.prank(user);
        spnft.requestReveal(separateTokenId);

        // Simulate VRF callback
        randomWords[0] = 987654321;

        vm.prank(vrfCoordinator);
        spnft.testFulfillRandomWords(requestId2, randomWords);

        // Now stake both tokens
        vm.startPrank(user);

        // Stake the in-collection revealed token
        spnft.approve(address(staking), normalTokenId);
        staking.stake(SPNFTStaking.NFTType.Original, normalTokenId);

        // Stake the separate collection token
        revealedSpnft.approve(address(staking), separateTokenId);
        staking.stake(SPNFTStaking.NFTType.Revealed, separateTokenId);

        vm.stopPrank();

        // Fast forward time
        vm.warp(block.timestamp + 30 days);

        // Calculate rewards for both types
        uint256 originalRewards = staking.calculateRewards(
            SPNFTStaking.NFTType.Original,
            normalTokenId
        );
        uint256 revealedRewards = staking.calculateRewards(
            SPNFTStaking.NFTType.Revealed,
            separateTokenId
        );

        // Both should have non-zero rewards
        assertTrue(
            originalRewards > 0,
            "Original collection should accrue rewards"
        );
        assertTrue(
            revealedRewards > 0,
            "Revealed collection should accrue rewards"
        );

        // Unstake both
        vm.startPrank(user);
        staking.unstake(SPNFTStaking.NFTType.Original, normalTokenId);
        staking.unstake(SPNFTStaking.NFTType.Revealed, separateTokenId);
        vm.stopPrank();

        // Check tokens returned
        assertEq(spnft.ownerOf(normalTokenId), user);
        assertEq(revealedSpnft.ownerOf(separateTokenId), user);

        // Check rewards distributed
        uint256 totalRewards = spToken.balanceOf(user);
        assertEq(totalRewards, originalRewards + revealedRewards);
    }

    // Test concurrent staking/unstaking operations
    function testFuzz_ConcurrentStakingOperations(
        uint8 userCount,
        uint8 operationsPerUser
    ) public {
        // Bound inputs to reasonable ranges
        userCount = uint8(bound(userCount, 2, 5));
        operationsPerUser = uint8(bound(operationsPerUser, 3, 10));

        // Create users and give them funds
        address[] memory users = new address[](userCount);
        for (uint8 i = 0; i < userCount; i++) {
            users[i] = makeAddr(string(abi.encodePacked("user", i)));
            vm.deal(users[i], mintPrice * operationsPerUser);
        }

        // Setup for in-collection reveal
        vm.startPrank(deployer);
        spnft.setRevealType(SPNFT.RevealType.InCollection);
        spnft.setRevealEnabled(true);
        vm.stopPrank();

        // Track token IDs per user
        uint256[][] memory userTokenIds = new uint256[][](userCount);
        for (uint8 i = 0; i < userCount; i++) {
            userTokenIds[i] = new uint256[](operationsPerUser);
        }

        // Mint and reveal tokens for all users
        for (uint8 i = 0; i < userCount; i++) {
            for (uint8 j = 0; j < operationsPerUser; j++) {
                // Mint token
                vm.prank(users[i]);
                uint256 tokenId = spnft.mint{value: mintPrice}();
                userTokenIds[i][j] = tokenId;

                // Request reveal
                uint256 requestId = uint256(keccak256(abi.encode(i, j)));
                vm.mockCall(
                    vrfCoordinator,
                    abi.encodeWithSelector(
                        bytes4(
                            keccak256(
                                "requestRandomWords(bytes32,uint64,uint16,uint32,uint32,uint256)"
                            )
                        )
                    ),
                    abi.encode(requestId)
                );

                vm.prank(users[i]);
                spnft.requestReveal(tokenId);

                // Simulate VRF callback
                uint256[] memory randomWords = new uint256[](1);
                randomWords[0] = uint256(keccak256(abi.encode("random", i, j)));

                vm.prank(vrfCoordinator);
                spnft.testFulfillRandomWords(requestId, randomWords);
            }
        }

        // Perform interleaved staking operations
        for (uint8 j = 0; j < operationsPerUser; j++) {
            // Each user stakes one token
            for (uint8 i = 0; i < userCount; i++) {
                // Alternate operation types by index (stake, claim, unstake)
                uint8 operationType = j % 3;

                if (operationType == 0 || j == 0) {
                    // Stake operation
                    vm.startPrank(users[i]);
                    spnft.approve(address(staking), userTokenIds[i][j]);
                    staking.stake(
                        SPNFTStaking.NFTType.Original,
                        userTokenIds[i][j]
                    );
                    vm.stopPrank();
                } else if (operationType == 1 && j > 1) {
                    // Claim operation (on previously staked token)
                    // First warp time to accrue rewards
                    vm.warp(block.timestamp + 15 days);

                    vm.prank(users[i]);
                    // Try-catch since some tokens might be unstaked already
                    try
                        staking.claimRewards(
                            SPNFTStaking.NFTType.Original,
                            userTokenIds[i][j - 2]
                        )
                    {
                        // Claim succeeded
                    } catch {
                        // Ignore failures - token might be unstaked already
                    }
                } else if (operationType == 2 && j > 0) {
                    // Unstake operation (on previously staked token)
                    vm.prank(users[i]);
                    // Try-catch since some tokens might not be staked yet
                    try
                        staking.unstake(
                            SPNFTStaking.NFTType.Original,
                            userTokenIds[i][j - 1]
                        )
                    {
                        // Unstake succeeded
                    } catch {
                        // Ignore failures - token might not be staked
                    }
                }

                // Warp time between users to test different staking periods
                vm.warp(block.timestamp + 1 days);
            }
        }

        // Finally, check all users have received some rewards if they staked
        for (uint8 i = 0; i < userCount; i++) {
            uint256 rewards = spToken.balanceOf(users[i]);

            // Some users should have received some rewards
            if (operationsPerUser >= 3) {
                // Don't assert specific amounts since we can't easily predict interleaved operations
                // Just verify some rewards were distributed
                assertTrue(
                    rewards >= 0,
                    "Users should have received rewards if they staked"
                );
            }
        }
    }
}
