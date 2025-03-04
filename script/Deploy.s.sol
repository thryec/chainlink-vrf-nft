// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/SPNFT.sol";
import "../src/RevealedSPNFT.sol";
import "../src/SPToken.sol";
import "../src/SPNFTStaking.sol";

contract DeployScript is Script {
    // Sepolia Chainlink VRF Coordinator
    address constant VRF_COORDINATOR =
        0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    bytes32 constant KEY_HASH =
        0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint64 constant SUBSCRIPTION_ID = 12295;

    function run() external {
        vm.startBroadcast();

        // Deploy the SP NFT contract
        SPNFT spnft = new SPNFT(
            "SP NFT",
            "SPNFT",
            0.01 ether, // Mint price
            1000, // Max supply
            VRF_COORDINATOR,
            KEY_HASH,
            SUBSCRIPTION_ID
        );

        // Deploy the Revealed SP NFT contract
        RevealedSPNFT revealedSpnft = new RevealedSPNFT(
            "Revealed SP NFT",
            "RSPNFT"
        );

        // Set the SP NFT contract as the minter for the Revealed SP NFT contract
        revealedSpnft.setSPNFTContract(address(spnft));

        // Set the revealed collection address in the SP NFT contract
        spnft.setRevealedCollectionAddress(address(revealedSpnft));

        // Deploy the SP Token contract for staking rewards
        SPToken spToken = new SPToken("SP Token", "SPT");

        // Deploy the staking contract
        SPNFTStaking staking = new SPNFTStaking(
            address(spnft),
            address(revealedSpnft),
            address(spToken)
        );

        // Set the staking contract as the minter for the SP Token
        spToken.setStakingContract(address(staking));

        // Set example metadata for the SP NFT contract
        string[] memory names = new string[](3);
        names[0] = "Red SP";
        names[1] = "Green SP";
        names[2] = "Blue SP";

        string[] memory descriptions = new string[](3);
        descriptions[0] = "A red SP NFT with special powers.";
        descriptions[1] = "A green SP NFT with unique abilities.";
        descriptions[2] = "A blue SP NFT with rare attributes.";

        string[] memory images = new string[](3);

        // SVG for red SP
        images[0] = string(
            abi.encodePacked(
                "data:image/svg+xml;base64,",
                Base64.encode(
                    bytes(
                        '<svg xmlns="http://www.w3.org/2000/svg" width="500" height="500"><rect width="500" height="500" fill="#FF0000"/><text x="50%" y="50%" font-family="Arial" font-size="24" fill="#fff" text-anchor="middle">Red SP</text></svg>'
                    )
                )
            )
        );

        // SVG for green SP
        images[1] = string(
            abi.encodePacked(
                "data:image/svg+xml;base64,",
                Base64.encode(
                    bytes(
                        '<svg xmlns="http://www.w3.org/2000/svg" width="500" height="500"><rect width="500" height="500" fill="#00FF00"/><text x="50%" y="50%" font-family="Arial" font-size="24" fill="#000" text-anchor="middle">Green SP</text></svg>'
                    )
                )
            )
        );

        // SVG for blue SP
        images[2] = string(
            abi.encodePacked(
                "data:image/svg+xml;base64,",
                Base64.encode(
                    bytes(
                        '<svg xmlns="http://www.w3.org/2000/svg" width="500" height="500"><rect width="500" height="500" fill="#0000FF"/><text x="50%" y="50%" font-family="Arial" font-size="24" fill="#fff" text-anchor="middle">Blue SP</text></svg>'
                    )
                )
            )
        );

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

        // Set metadata for the SP NFT contract
        spnft.setMetadata(names, descriptions, images, attributes);

        // Set metadata for the Revealed SP NFT contract
        revealedSpnft.setMetadata(names, descriptions, images, attributes);

        // Enable minting
        spnft.setMintEnabled(true);

        vm.stopBroadcast();

        console.log("Deployment complete!");
        console.log("SPNFT deployed at:", address(spnft));
        console.log("RevealedSPNFT deployed at:", address(revealedSpnft));
        console.log("SPToken deployed at:", address(spToken));
        console.log("SPNFTStaking deployed at:", address(staking));
    }
}
