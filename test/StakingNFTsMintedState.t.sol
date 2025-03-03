// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StakingDeployedState.t.sol";

/**
 * @title StakingNFTsMintedState
 * @dev State with both types of NFTs minted and ready to be staked
 */
abstract contract StakingNFTsMintedState is StakingDeployedState {
    // Original collection (in-collection revealed) tokens
    uint256 internal originalTokenId1;
    uint256 internal originalTokenId2;

    // Revealed collection (separate collection) tokens
    uint256 internal revealedTokenId1;
    uint256 internal revealedTokenId2;

    uint256 internal requestId;

    function setUp() public virtual override {
        super.setUp();

        // Mint tokens to users
        vm.deal(user1, mintPrice * 5);
        vm.deal(user2, mintPrice * 3);

        // User1 mints tokens from original collection (in-collection reveals)
        vm.startPrank(user1);
        originalTokenId1 = spnftWithVRF.mint{value: mintPrice}();
        originalTokenId2 = spnftWithVRF.mint{value: mintPrice}();
        vm.stopPrank();

        // User2 mints tokens from original collection
        vm.startPrank(user2);
        spnftWithVRF.mint{value: mintPrice}(); // tokenId 3
        vm.stopPrank();

        // Mint and Reveal in Separate Collection

        // 1. First switch to separate collection reveal
        vm.prank(deployer);
        spnftWithVRF.setRevealType(SPNFT.RevealType.SeparateCollection);

        // 2. Mint tokens to be revealed later
        vm.startPrank(user1);
        uint256 tokenToReveal1 = spnftWithVRF.mint{value: mintPrice}();
        uint256 tokenToReveal2 = spnftWithVRF.mint{value: mintPrice}();
        vm.stopPrank();

        vm.startPrank(user2);
        uint256 tokenToReveal3 = spnftWithVRF.mint{value: mintPrice}();
        vm.stopPrank();

        // 3. Enable revealing
        vm.prank(deployer);
        spnftWithVRF.setRevealEnabled(true);

        // Request reveals with separate requestIds
        uint256 requestId1 = 123;
        uint256 requestId2 = 124;
        uint256 requestId3 = 125;

        // Mock the VRF calls with separate requestIds
        vm.mockCall(
            mockVrfCoordinator,
            abi.encodeWithSelector(
                VRFCoordinatorV2Interface.requestRandomWords.selector
            ),
            abi.encode(requestId1)
        );

        vm.startPrank(user1);
        spnftWithVRF.requestReveal(tokenToReveal1);
        vm.stopPrank();

        // Mock the VRF calls with separate requestIds
        vm.mockCall(
            mockVrfCoordinator,
            abi.encodeWithSelector(
                VRFCoordinatorV2Interface.requestRandomWords.selector
            ),
            abi.encode(requestId2)
        );

        vm.startPrank(user1);
        spnftWithVRF.requestReveal(tokenToReveal2);
        vm.stopPrank();

        // Mock the VRF calls with separate requestIds
        vm.mockCall(
            mockVrfCoordinator,
            abi.encodeWithSelector(
                VRFCoordinatorV2Interface.requestRandomWords.selector
            ),
            abi.encode(requestId3)
        );

        vm.prank(user2);
        spnftWithVRF.requestReveal(tokenToReveal3);

        // Simulate VRF callbacks for each request
        _simulateVRFCallback(requestId1, 12345);
        _simulateVRFCallback(requestId2, 67890);
        _simulateVRFCallback(requestId3, 13579);

        // When using separate collection reveal, the original tokens are burned
        // and new tokens with the same IDs are created in the revealed collection
        revealedTokenId1 = tokenToReveal1;
        revealedTokenId2 = tokenToReveal2;

        console.log(
            "User1 original collection balance:",
            spnftWithVRF.balanceOf(user1)
        );
        console.log(
            "User1 revealed collection balance:",
            revealedSpnft.balanceOf(user1)
        );
        console.log(
            "User2 original collection balance:",
            spnftWithVRF.balanceOf(user2)
        );
        console.log(
            "User2 revealed collection balance:",
            revealedSpnft.balanceOf(user2)
        );

        // Verify that the revealed tokens exist in the revealed collection
        assertTrue(
            revealedSpnft.ownerOf(revealedTokenId1) == user1,
            "Revealed token 1 should be owned by user1 in the revealed collection"
        );
        assertTrue(
            revealedSpnft.ownerOf(revealedTokenId2) == user1,
            "Revealed token 2 should be owned by user1 in the revealed collection"
        );

        // Reveal in-collection tokens (original collection)
        vm.startPrank(deployer);
        spnftWithVRF.setRevealEnabled(false);
        spnftWithVRF.setRevealType(SPNFT.RevealType.InCollection);
        spnftWithVRF.setRevealEnabled(true);
        vm.stopPrank();

        // Request reveal for originalTokenId1
        uint256 requestId4 = 126;
        uint256 requestId5 = 127;

        vm.mockCall(
            mockVrfCoordinator,
            abi.encodeWithSelector(
                VRFCoordinatorV2Interface.requestRandomWords.selector
            ),
            abi.encode(requestId4)
        );

        vm.startPrank(user1);
        spnftWithVRF.requestReveal(originalTokenId1);
        vm.stopPrank();

        vm.mockCall(
            mockVrfCoordinator,
            abi.encodeWithSelector(
                VRFCoordinatorV2Interface.requestRandomWords.selector
            ),
            abi.encode(requestId5)
        );

        vm.startPrank(user1);
        spnftWithVRF.requestReveal(originalTokenId2);
        vm.stopPrank();

        _simulateVRFCallback(requestId4, 98765);
        _simulateVRFCallback(requestId5, 45612);
    }
}

/**
 * @title StakingNFTsMintedTest
 * @dev Tests for the state with NFTs minted and ready to be staked
 */
contract StakingNFTsMintedTest is StakingNFTsMintedState {
    function testAllTokensRevealed() public {
        assertTrue(
            spnftWithVRF.isRevealed(originalTokenId1),
            "In-collection token 1 should be revealed"
        );
        assertTrue(
            spnftWithVRF.isRevealed(originalTokenId2),
            "In-collection token 2 should be revealed"
        );
        assertTrue(
            spnftWithVRF.isRevealed(revealedTokenId1),
            "Separate collection token 1 should be revealed"
        );

        assertTrue(
            spnftWithVRF.isRevealed(revealedTokenId2),
            "Separate collection token 2 should be revealed"
        );
    }

    function testOriginalNFTsCorrectlyMinted() public {
        assertEq(spnftWithVRF.ownerOf(originalTokenId1), user1);
        assertEq(spnftWithVRF.ownerOf(originalTokenId2), user1);

        // User1 should have exactly 2 tokens in the original collection
        // (since the other 2 tokens were moved to the revealed collection)
        assertEq(spnftWithVRF.balanceOf(user1), 2);
    }

    function testRevealedNFTsCorrectlyMinted() public {
        // Verify the tokens are in the revealed collection
        assertEq(revealedSpnft.ownerOf(revealedTokenId1), user1);
        assertEq(revealedSpnft.ownerOf(revealedTokenId2), user1);

        // Verify the tokens are NOT in the original collection (they were burned)
        vm.expectRevert();
        spnftWithVRF.ownerOf(revealedTokenId1);

        vm.expectRevert();
        spnftWithVRF.ownerOf(revealedTokenId2);

        // Check the balance in each collection
        assertEq(revealedSpnft.balanceOf(user1), 2); // User1 has 2 revealed tokens
        assertEq(revealedSpnft.balanceOf(user2), 1); // User2 has 1 revealed token
    }

    function testStakeOriginalCollection() public {
        vm.startPrank(user1);

        // Approve and stake the first original NFT
        spnftWithVRF.approve(address(staking), originalTokenId1);
        staking.stake(SPNFTStaking.NFTType.Original, originalTokenId1);

        vm.stopPrank();

        // Check ownership transferred to staking contract
        assertEq(spnftWithVRF.ownerOf(originalTokenId1), address(staking));

        // Check staked tokens list
        uint256[] memory stakedTokens = staking.getStakedOriginalTokens(user1);
        assertEq(stakedTokens.length, 1);
        assertEq(stakedTokens[0], originalTokenId1);

        // Check total staked count
        assertEq(staking.getTotalStakedByOwner(user1), 1);
    }

    function testStakeRevealedCollection() public {
        vm.startPrank(user1);

        // Approve and stake the first revealed NFT
        revealedSpnft.approve(address(staking), revealedTokenId1);
        staking.stake(SPNFTStaking.NFTType.Revealed, revealedTokenId1);

        vm.stopPrank();

        // Check ownership transferred to staking contract
        assertEq(revealedSpnft.ownerOf(revealedTokenId1), address(staking));

        // Check staked tokens list
        uint256[] memory stakedTokens = staking.getStakedRevealedTokens(user1);
        assertEq(stakedTokens.length, 1);
        assertEq(stakedTokens[0], revealedTokenId1);

        // Check total staked count
        assertEq(staking.getTotalStakedByOwner(user1), 1);
    }

    function testStakeBothCollections() public {
        vm.startPrank(user1);

        // Stake from original collection
        spnftWithVRF.approve(address(staking), originalTokenId1);
        staking.stake(SPNFTStaking.NFTType.Original, originalTokenId1);

        // Stake from revealed collection
        revealedSpnft.approve(address(staking), revealedTokenId1);
        staking.stake(SPNFTStaking.NFTType.Revealed, revealedTokenId1);

        vm.stopPrank();

        // Check ownership transferred for both tokens
        assertEq(spnftWithVRF.ownerOf(originalTokenId1), address(staking));
        assertEq(revealedSpnft.ownerOf(revealedTokenId1), address(staking));

        // Check staked tokens lists
        uint256[] memory originalTokens;
        uint256[] memory revealedTokens;
        (originalTokens, revealedTokens) = staking.getAllStakedTokens(user1);

        assertEq(originalTokens.length, 1);
        assertEq(originalTokens[0], originalTokenId1);

        assertEq(revealedTokens.length, 1);
        assertEq(revealedTokens[0], revealedTokenId1);

        // Check total staked count
        assertEq(staking.getTotalStakedByOwner(user1), 2);
    }
}
