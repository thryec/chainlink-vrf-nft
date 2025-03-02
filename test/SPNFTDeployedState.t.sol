// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StateZero.t.sol";
import "forge-std/console.sol";

/**
 * @title SPNFTDeployedState
 * @dev State with SPNFT contract deployed but no tokens minted yet
 */
abstract contract SPNFTDeployedState is StateZero {
    SPNFTWithExposedVRF internal spnft;
    RevealedSPNFT internal revealedSpnft;

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(deployer);

        // Deploy SP NFT contract
        spnft = new SPNFTWithExposedVRF(
            "SP NFT",
            "SPNFT",
            mintPrice,
            maxSupply,
            mockVrfCoordinator,
            keyHash,
            subscriptionId
        );

        // Deploy Revealed SPNFT contract
        revealedSpnft = new RevealedSPNFT("Revealed SP NFT", "RSPNFT");

        // Set the SP NFT contract as the minter for the Revealed SPNFT
        revealedSpnft.setSPNFTContract(address(spnft));

        // Set the Revealed SPNFT address in the SP NFT contract
        spnft.setRevealedCollectionAddress(address(revealedSpnft));

        // Set metadata for both contracts
        spnft.setMetadata(names, descriptions, images, attributes);
        revealedSpnft.setMetadata(names, descriptions, images, attributes);

        // Enable minting
        spnft.setMintEnabled(true);

        vm.stopPrank();

        // Label contracts
        vm.label(address(spnft), "SPNFT");
        vm.label(address(revealedSpnft), "RevealedSPNFT");
    }

    // Helper to get tokens ready for minting
    function _dealTokens(address to, uint256 amount) internal {
        vm.deal(to, amount);
    }
}

/**
 * @title SPNFTDeployedTest
 * @dev Test contract for the initial state of the SPNFT contract
 */
contract SPNFTDeployedTest is SPNFTDeployedState {
    function testInitialState() public {
        assertEq(spnft.name(), "SP NFT");
        assertEq(spnft.symbol(), "SPNFT");
        assertEq(spnft.totalSupply(), 0);
        assertEq(spnft.mintEnabled(), true);
        assertEq(spnft.revealEnabled(), false);
        assertEq(
            uint256(spnft.revealType()),
            uint256(SPNFT.RevealType.InCollection)
        );
    }

    function testMintToken() public {
        _dealTokens(user1, mintPrice);

        vm.startPrank(user1);

        uint256 tokenId = spnft.mint{value: mintPrice}();

        // Check owner and balance
        assertEq(spnft.ownerOf(tokenId), user1);
        assertEq(spnft.balanceOf(user1), 1);

        vm.stopPrank();
    }

    function testMintWithExcessPayment() public {
        uint256 excessPayment = mintPrice * 2;
        _dealTokens(user1, excessPayment);

        uint256 initialBalance = user1.balance;

        vm.startPrank(user1);

        spnft.mint{value: excessPayment}();

        // Check refund
        assertEq(user1.balance, initialBalance - mintPrice);

        vm.stopPrank();
    }

    function testMintRevertsWithInsufficientPayment() public {
        _dealTokens(user1, mintPrice / 2);

        vm.startPrank(user1);

        vm.expectRevert("Insufficient payment");
        spnft.mint{value: mintPrice / 2}();

        vm.stopPrank();
    }

    function testSetRevealType() public {
        vm.startPrank(deployer);

        // Test setting to InCollection (already default, but testing the function)
        spnft.setRevealType(SPNFT.RevealType.InCollection);
        assertEq(
            uint256(spnft.revealType()),
            uint256(SPNFT.RevealType.InCollection)
        );

        // Test setting to SeparateCollection
        spnft.setRevealType(SPNFT.RevealType.SeparateCollection);
        assertEq(
            uint256(spnft.revealType()),
            uint256(SPNFT.RevealType.SeparateCollection)
        );

        vm.stopPrank();
    }

    function testSetRevealTypeEmitsEvent() public {
        vm.startPrank(deployer);

        // Test that setting reveal type emits the correct event
        vm.expectEmit(true, true, true, true);
        emit SPNFT.RevealTypeSet(SPNFT.RevealType.SeparateCollection);
        spnft.setRevealType(SPNFT.RevealType.SeparateCollection);

        vm.stopPrank();
    }

    function testSetRevealTypeRevertsWhenNotOwner() public {
        vm.startPrank(user1);

        vm.expectRevert();
        spnft.setRevealType(SPNFT.RevealType.SeparateCollection);

        vm.stopPrank();
    }

    function testMintRevertsWhenDisabled() public {
        vm.prank(deployer);
        spnft.setMintEnabled(false);

        _dealTokens(user1, mintPrice);

        vm.startPrank(user1);

        vm.expectRevert("Minting is not enabled");
        spnft.mint{value: mintPrice}();

        vm.stopPrank();
    }
}
