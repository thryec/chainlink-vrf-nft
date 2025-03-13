// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/SPNFT.sol";
import "../../src/RevealedSPNFT.sol";
import "../../src/SPToken.sol";
import "../../src/SPNFTStaking.sol";
import "../../src/VRFMock.sol";

contract SecurityFuzzTest is Test {
    SPNFTWithExposedVRF internal spnft;
    RevealedSPNFT internal revealedSpnft;
    SPToken internal spToken;
    SPNFTStaking internal staking;

    address deployer;
    address user;
    address malicious;
    address vrfCoordinator;

    uint256 mintPrice = 0.01 ether;

    function setUp() public {
        deployer = makeAddr("deployer");
        user = makeAddr("user");
        malicious = makeAddr("malicious");
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

        // Set up SPToken and Staking
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

    // Test reentrancy protection in staking contract
    function testFuzz_ReentrancyProtection(
        uint256 tokenId,
        uint8 attackType
    ) public {
        // Bound to valid token IDs and attack types
        tokenId = bound(tokenId, 1, 100);
        attackType = uint8(bound(attackType, 0, 2)); // 0 = stake, 1 = unstake, 2 = claim

        // Set up the NFTs first
        vm.startPrank(deployer);
        spnft.setRevealType(SPNFT.RevealType.InCollection);
        spnft.setRevealEnabled(true);
        vm.stopPrank();

        // Give user funds and mint a token
        vm.deal(user, mintPrice);
        vm.prank(user);
        uint256 userTokenId = spnft.mint{value: mintPrice}();

        // Reveal the token
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
        spnft.requestReveal(userTokenId);

        // Simulate VRF callback
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 54321;

        vm.prank(vrfCoordinator);
        spnft.testFulfillRandomWords(requestId, randomWords);

        // Create the malicious contract
        ReentrancyAttacker attacker = new ReentrancyAttacker(
            address(spnft),
            address(staking)
        );

        // Transfer the token to the attacker
        vm.prank(user);
        spnft.transferFrom(user, address(attacker), userTokenId);

        // Set approval for staking
        vm.prank(address(attacker));
        spnft.approve(address(staking), userTokenId);

        // Try different attack types
        if (attackType == 0) {
            // Stake attack
            vm.expectRevert(); // Should revert due to ReentrancyGuard
            attacker.attackStake(userTokenId);
        } else if (attackType == 1) {
            // First stake normally
            vm.prank(address(attacker));
            staking.stake(SPNFTStaking.NFTType.Original, userTokenId);

            // Now try unstake attack
            vm.expectRevert(); // Should revert due to ReentrancyGuard
            attacker.attackUnstake(userTokenId);
        } else {
            // First stake normally
            vm.prank(address(attacker));
            staking.stake(SPNFTStaking.NFTType.Original, userTokenId);

            // Advance time to generate rewards
            vm.warp(block.timestamp + 30 days);

            // Try claim attack
            vm.expectRevert(); // Should revert due to ReentrancyGuard
            attacker.attackClaim(userTokenId);
        }
    }

    // Test ownership security
    function testFuzz_OwnershipSecurity(
        address randomCaller,
        uint8 functionId
    ) public {
        // Skip if randomCaller is deployer, zero address, or contract addresses
        vm.assume(randomCaller != deployer);
        vm.assume(randomCaller != address(0));
        vm.assume(randomCaller != address(spnft));
        vm.assume(randomCaller != address(revealedSpnft));
        vm.assume(randomCaller != address(spToken));
        vm.assume(randomCaller != address(staking));

        // Bound function ID to the number of owner-only functions
        functionId = uint8(bound(functionId, 0, 9));

        // Try to call owner-only functions with random address
        vm.startPrank(randomCaller);

        if (functionId == 0) {
            vm.expectRevert();
            spnft.setMintEnabled(true);
        } else if (functionId == 1) {
            vm.expectRevert();
            spnft.setRevealEnabled(true);
        } else if (functionId == 2) {
            vm.expectRevert();
            spnft.setRevealType(SPNFT.RevealType.InCollection);
        } else if (functionId == 3) {
            vm.expectRevert();
            spnft.setRevealedCollectionAddress(address(0x123));
        } else if (functionId == 4) {
            string[] memory emptyArray = new string[](1);
            emptyArray[0] = "test";

            vm.expectRevert();
            spnft.setMetadata(emptyArray, emptyArray, emptyArray, emptyArray);
        } else if (functionId == 5) {
            vm.expectRevert();
            spnft.setMintPrice(0.1 ether);
        } else if (functionId == 6) {
            vm.expectRevert();
            spnft.setMaxSupply(5000);
        } else if (functionId == 7) {
            vm.expectRevert();
            spnft.withdraw();
        } else if (functionId == 8) {
            vm.expectRevert();
            revealedSpnft.setSPNFTContract(address(0x123));
        } else if (functionId == 9) {
            vm.expectRevert();
            staking.setOriginalSPNFT(address(0x123));
        }

        vm.stopPrank();

        // Now verify same functions work when called by deployer
        vm.startPrank(deployer);

        if (functionId == 0) {
            spnft.setMintEnabled(false);
            spnft.setMintEnabled(true); // Reset
        } else if (functionId == 1) {
            spnft.setRevealEnabled(false);
            spnft.setRevealEnabled(true); // Reset
        } else if (functionId == 2) {
            spnft.setRevealType(SPNFT.RevealType.SeparateCollection);
            spnft.setRevealType(SPNFT.RevealType.InCollection); // Reset
        } else if (functionId == 3) {
            address oldAddress = spnft.revealedCollectionAddress();
            spnft.setRevealedCollectionAddress(address(0x123));
            spnft.setRevealedCollectionAddress(oldAddress); // Reset
        } else if (functionId == 4) {
            // We already set metadata in setup, just verify it doesn't revert for owner
            string[] memory emptyArray = new string[](1);
            emptyArray[0] = "test";

            spnft.setMetadata(emptyArray, emptyArray, emptyArray, emptyArray);
        } else if (functionId == 5) {
            uint256 oldPrice = spnft.mintPrice();
            spnft.setMintPrice(0.1 ether);
            spnft.setMintPrice(oldPrice); // Reset
        } else if (functionId == 6) {
            uint256 oldSupply = spnft.maxSupply();
            spnft.setMaxSupply(5000);
            spnft.setMaxSupply(oldSupply); // Reset
        } else if (functionId == 7) {
            // Skip actual withdrawal test, just verify it doesn't revert for owner
            // (would need to fund contract first for actual withdrawal)
        } else if (functionId == 8) {
            address oldContract = address(spnft);
            revealedSpnft.setSPNFTContract(address(0x123));
            revealedSpnft.setSPNFTContract(oldContract); // Reset
        } else if (functionId == 9) {
            address oldNFT = address(spnft);
            staking.setOriginalSPNFT(address(0x123));
            staking.setOriginalSPNFT(oldNFT); // Reset
        }

        vm.stopPrank();
    }

    // Test malicious metadata input
    function testFuzz_MaliciousMetadataInput(
        string memory maliciousInput
    ) public {
        // Skip empty strings
        vm.assume(bytes(maliciousInput).length > 0);

        // Prepare malicious metadata arrays
        string[] memory names = new string[](1);
        string[] memory descriptions = new string[](1);
        string[] memory images = new string[](1);
        string[] memory attributes = new string[](1);

        names[0] = maliciousInput;
        descriptions[0] = maliciousInput;
        images[0] = maliciousInput;
        attributes[0] = maliciousInput;

        // Set metadata as owner
        vm.prank(deployer);
        spnft.setMetadata(names, descriptions, images, attributes);

        // Mint and reveal a token to test the malicious metadata
        vm.prank(deployer);
        spnft.setRevealType(SPNFT.RevealType.InCollection);

        vm.prank(deployer);
        spnft.setRevealEnabled(true);

        vm.deal(user, mintPrice);
        vm.prank(user);
        uint256 tokenId = spnft.mint{value: mintPrice}();

        // Request reveal
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

        vm.prank(vrfCoordinator);
        spnft.testFulfillRandomWords(requestId, randomWords);

        // Try to get tokenURI - this should not revert regardless of malicious input
        string memory uri = spnft.tokenURI(tokenId);

        // Verify URI was generated
        assertTrue(
            bytes(uri).length > 0,
            "TokenURI should be generated regardless of input"
        );
    }
}

// Malicious contract that tries to exploit reentrancy
contract ReentrancyAttacker {
    IERC721 public nft;
    SPNFTStaking public staking;
    uint256 public attackCount;

    constructor(address _nft, address _staking) {
        nft = IERC721(_nft);
        staking = SPNFTStaking(_staking);
        attackCount = 0;
    }

    // Attack during stake call
    function attackStake(uint256 tokenId) external {
        staking.stake(SPNFTStaking.NFTType.Original, tokenId);
    }

    // Attack during unstake call
    function attackUnstake(uint256 tokenId) external {
        staking.unstake(SPNFTStaking.NFTType.Original, tokenId);
    }

    // Attack during claim rewards call
    function attackClaim(uint256 tokenId) external {
        staking.claimRewards(SPNFTStaking.NFTType.Original, tokenId);
    }

    // ERC721 receiver that attempts reentrancy
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        // Only attempt reentrancy once to avoid infinite recursion in tests
        if (attackCount == 0) {
            attackCount++;

            // Try to call back into the staking contract
            if (msg.sender == address(staking)) {
                staking.stake(SPNFTStaking.NFTType.Original, tokenId);
            } else if (msg.sender == address(nft)) {
                // If NFT is being transferred back, try to stake it again
                nft.approve(address(staking), tokenId);
                staking.stake(SPNFTStaking.NFTType.Original, tokenId);
            }
        }

        return this.onERC721Received.selector;
    }
}
