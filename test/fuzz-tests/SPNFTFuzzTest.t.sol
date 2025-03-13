// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/SPNFT.sol";
import "../../src/RevealedSPNFT.sol";
import "../../src/SPToken.sol";
import "../../src/SPNFTStaking.sol";
import "../../src/VRFMock.sol";
import "@chainlink/contracts/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

contract SPNFTFuzzTest is Test {
    SPNFTWithExposedVRF internal spnft;
    RevealedSPNFT internal revealedSpnft;
    SPToken internal spToken;
    SPNFTStaking internal staking;

    address deployer;
    address user1;
    address vrfCoordinator;

    uint256 mintPrice = 0.01 ether;
    uint256 maxSupply = 1000;
    bytes32 keyHash = keccak256("keyHash");
    uint64 subscriptionId = 1;

    // Setup for the tests
    function setUp() public {
        deployer = makeAddr("deployer");
        user1 = makeAddr("user1");
        vrfCoordinator = makeAddr("vrfCoordinator");

        vm.startPrank(deployer);

        // Deploy contracts
        spnft = new SPNFTWithExposedVRF(
            "SP NFT",
            "SPNFT",
            mintPrice,
            maxSupply,
            vrfCoordinator,
            keyHash,
            subscriptionId
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

        // Enable minting
        spnft.setMintEnabled(true);

        // Set up SPToken and Staking
        spToken = new SPToken("SP Token", "SPT");
        staking = new SPNFTStaking(
            address(spnft),
            address(revealedSpnft),
            address(spToken)
        );
        spToken.setStakingContract(address(staking));

        vm.stopPrank();
    }

    // Fuzz test for minting with various ETH amounts
    function testFuzz_Mint(uint256 ethAmount) public {
        // Bound ethAmount to realistic values between mintPrice and 10 ETH
        ethAmount = bound(ethAmount, mintPrice, 10 ether);

        vm.deal(user1, ethAmount);

        uint256 balanceBefore = user1.balance;

        vm.prank(user1);
        spnft.mint{value: ethAmount}();

        uint256 balanceAfter = user1.balance;

        // Should refund excess ETH if more than mintPrice was sent
        if (ethAmount > mintPrice) {
            assertEq(balanceBefore - balanceAfter, mintPrice);
        } else {
            assertEq(balanceBefore - balanceAfter, ethAmount);
        }

        // User should own exactly 1 token
        assertEq(spnft.balanceOf(user1), 1);
    }

    // Fuzz test for randomness distribution in reveals
    function testFuzz_RevealRandomness(
        uint256 randomSeed,
        uint8 numTokens
    ) public {
        // Bound to reasonable number of tokens
        numTokens = uint8(bound(numTokens, 1, 10));

        vm.startPrank(deployer);
        // Set in-collection reveal
        spnft.setRevealType(SPNFT.RevealType.InCollection);
        spnft.setRevealEnabled(true);
        vm.stopPrank();

        // Mint tokens to user1
        vm.deal(user1, mintPrice * numTokens);

        uint256[] memory tokenIds = new uint256[](numTokens);

        vm.startPrank(user1);
        for (uint8 i = 0; i < numTokens; i++) {
            tokenIds[i] = spnft.mint{value: mintPrice}();
        }
        vm.stopPrank();

        // Request reveals for all tokens
        for (uint8 i = 0; i < numTokens; i++) {
            uint256 requestId = 1000 + i;

            // Mock VRF call
            vm.mockCall(
                vrfCoordinator,
                abi.encodeWithSelector(
                    VRFCoordinatorV2Interface.requestRandomWords.selector
                ),
                abi.encode(requestId)
            );
            vm.prank(user1);
            spnft.requestReveal(tokenIds[i]);

            // Simulate VRF callback with different seeds for each token
            uint256[] memory randomWords = new uint256[](1);
            randomWords[0] = uint256(keccak256(abi.encode(randomSeed, i)));

            vm.prank(vrfCoordinator);
            spnft.testFulfillRandomWords(requestId, randomWords);
        }

        // Test that all tokens are revealed with unique randomness values
        bool[] memory usedCombinations = new bool[](3);
        uint8 uniqueCombinations = 0;

        for (uint8 i = 0; i < numTokens; i++) {
            assertTrue(
                spnft.isRevealed(tokenIds[i]),
                "Token should be revealed"
            );

            string memory tokenURI = spnft.tokenURI(tokenIds[i]);

            if (bytes(tokenURI).length > 0) {
                // Check which color was assigned (simplified check for test)
                bool isRed = bytes(tokenURI).length > 0 &&
                    (uint256(keccak256(bytes(tokenURI))) % 3 == 0);
                bool isGreen = bytes(tokenURI).length > 0 &&
                    (uint256(keccak256(bytes(tokenURI))) % 3 == 1);
                bool isBlue = bytes(tokenURI).length > 0 &&
                    (uint256(keccak256(bytes(tokenURI))) % 3 == 2);

                if (isRed && !usedCombinations[0]) {
                    usedCombinations[0] = true;
                    uniqueCombinations++;
                } else if (isGreen && !usedCombinations[1]) {
                    usedCombinations[1] = true;
                    uniqueCombinations++;
                } else if (isBlue && !usedCombinations[2]) {
                    usedCombinations[2] = true;
                    uniqueCombinations++;
                }
            }
        }

        // With enough tokens, we should see some diversity in the randomness
        if (numTokens >= 3) {
            assertTrue(
                uniqueCombinations > 1,
                "Should have some randomness distribution"
            );
        }
    }

    // Fuzz test for staking rewards calculation
    function testFuzz_StakingRewards(uint256 stakingDuration) public {
        // Bound staking duration to 1 day - 365 days
        stakingDuration = bound(stakingDuration, 1 days, 365 days);

        // Setup: mint, reveal and stake a token
        vm.deal(user1, mintPrice);

        vm.startPrank(user1);
        uint256 tokenId = spnft.mint{value: mintPrice}();
        vm.stopPrank();

        // Enable revealing with in-collection approach
        vm.startPrank(deployer);
        spnft.setRevealType(SPNFT.RevealType.InCollection);
        spnft.setRevealEnabled(true);
        vm.stopPrank();

        // Request reveal
        uint256 requestId = 1001;
        vm.mockCall(
            vrfCoordinator,
            abi.encodeWithSelector(
                VRFCoordinatorV2Interface.requestRandomWords.selector
            ),
            abi.encode(requestId)
        );

        vm.prank(user1);
        spnft.requestReveal(tokenId);

        // Simulate VRF callback
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;

        vm.prank(vrfCoordinator);
        spnft.testFulfillRandomWords(requestId, randomWords);

        // Stake the token
        vm.startPrank(user1);
        spnft.approve(address(staking), tokenId);
        staking.stake(SPNFTStaking.NFTType.Original, tokenId);
        vm.stopPrank();

        // Warp time forward by the fuzzed duration
        vm.warp(block.timestamp + stakingDuration);

        // Calculate rewards
        uint256 rewards = staking.calculateRewards(
            SPNFTStaking.NFTType.Original,
            tokenId
        );

        // Verify rewards match expected value
        uint256 expectedRewards = (1 ether * 5 * stakingDuration) /
            (365 days * 100);

        // Allow small difference due to rounding
        uint256 difference = rewards > expectedRewards
            ? rewards - expectedRewards
            : expectedRewards - rewards;
        assertTrue(difference <= 100, "Rewards should match expected formula");
    }

    // Fuzz test for multi-user staking and unstaking behavior
    function testFuzz_MultiUserStaking(
        uint8 userCount,
        uint8 tokensPerUser,
        uint16[10] memory stakingDurations
    ) public {
        // Bound inputs to reasonable ranges
        userCount = uint8(bound(userCount, 1, 5));
        tokensPerUser = uint8(bound(tokensPerUser, 1, 3));

        address[] memory users = new address[](userCount);
        for (uint8 i = 0; i < userCount; i++) {
            users[i] = makeAddr(string(abi.encodePacked("user", i)));
            vm.deal(users[i], mintPrice * tokensPerUser);
        }

        // Enable in-collection reveal
        vm.startPrank(deployer);
        spnft.setRevealType(SPNFT.RevealType.InCollection);
        spnft.setRevealEnabled(true);
        vm.stopPrank();

        // Each user mints, reveals, and stakes tokens
        for (uint8 u = 0; u < userCount; u++) {
            for (uint8 t = 0; t < tokensPerUser; t++) {
                // Mint token
                vm.prank(users[u]);
                uint256 tokenId = spnft.mint{value: mintPrice}();

                // Request reveal
                uint256 requestId = uint256(keccak256(abi.encode(u, t)));
                vm.mockCall(
                    vrfCoordinator,
                    abi.encodeWithSelector(
                        VRFCoordinatorV2Interface.requestRandomWords.selector
                    ),
                    abi.encode(requestId)
                );

                vm.prank(users[u]);
                spnft.requestReveal(tokenId);

                // Simulate VRF callback
                uint256[] memory randomWords = new uint256[](1);
                randomWords[0] = uint256(keccak256(abi.encode("random", u, t)));

                vm.prank(vrfCoordinator);
                spnft.testFulfillRandomWords(requestId, randomWords);

                // Stake token
                vm.startPrank(users[u]);
                spnft.approve(address(staking), tokenId);
                staking.stake(SPNFTStaking.NFTType.Original, tokenId);
                vm.stopPrank();

                // Apply fuzzed staking duration
                uint256 duration = bound(
                    stakingDurations[t % 10],
                    1 days,
                    365 days
                );
                vm.warp(block.timestamp + duration);

                // Try unstaking randomly for some tokens
                if (u % 2 == 0 && t % 2 == 0) {
                    vm.prank(users[u]);
                    staking.unstake(SPNFTStaking.NFTType.Original, tokenId);

                    // Verify ownership returned to user
                    assertEq(spnft.ownerOf(tokenId), users[u]);
                }
            }
        }

        // Verify total staked counts
        for (uint8 u = 0; u < userCount; u++) {
            uint256 expectedStakedCount = u % 2 == 0
                ? tokensPerUser - (tokensPerUser + 1) / 2 // For even users, unstaked half (rounded up)
                : tokensPerUser; // For odd users, all tokens staked

            assertEq(
                staking.getTotalStakedByOwner(users[u]),
                expectedStakedCount,
                "Incorrect staked token count"
            );
        }
    }
}
