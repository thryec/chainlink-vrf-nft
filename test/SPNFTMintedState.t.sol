// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23;

import "./SPNFTDeployedState.t.sol";

/**
 * @title SPNFTMintedState
 * @dev State with SPNFT tokens minted but not yet revealed
 */
abstract contract SPNFTMintedState is SPNFTDeployedState {
    uint256 internal tokenId1;
    uint256 internal tokenId2;

    function setUp() public virtual override {
        super.setUp();

        // Mint tokens to users
        _dealTokens(user1, mintPrice * 2);
        _dealTokens(user2, mintPrice);

        vm.startPrank(user1);
        tokenId1 = spnft.mint{value: mintPrice}();
        tokenId2 = spnft.mint{value: mintPrice}();
        vm.stopPrank();

        vm.prank(user2);
        spnft.mint{value: mintPrice}(); // tokenId 3 to user2
    }
}

/**
 * @title SPNFTMintedTest
 * @dev Test contract for minted but unrevealed NFTs
 */
contract SPNFTMintedTest is SPNFTMintedState {
    function testUnrevealedTokenURI() public {
        string memory uri = spnft.tokenURI(tokenId1);

        string memory expectedURI = spnft.generateUnrevealedMetadata(tokenId1);

        assertEq(uri, expectedURI);
    }

    function testRevealNotEnabledYet() public {
        assertEq(spnft.revealEnabled(), false);

        vm.startPrank(user1);
        vm.expectRevert("Revealing is not enabled");
        spnft.requestReveal(tokenId1);

        vm.stopPrank();
    }

    function testOperatorSetRevealType() public {
        vm.startPrank(deployer);
        spnft.setRevealType(SPNFT.RevealType.InCollection);
        vm.stopPrank();

        assertEq(
            uint256(spnft.revealType()),
            uint256(SPNFT.RevealType.InCollection)
        );
    }

    function testOwnershipCorrect() public {
        assertEq(spnft.ownerOf(tokenId1), user1);
        assertEq(spnft.ownerOf(tokenId2), user1);
        assertEq(spnft.balanceOf(user1), 2);
        assertEq(spnft.balanceOf(user2), 1);
    }
}
