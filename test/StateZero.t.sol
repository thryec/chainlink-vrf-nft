// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/SPNFTWithExposedVRF.sol";
import "../src/RevealedSPNFT.sol";
import "../src/SPToken.sol";
import "../src/SPNFTStaking.sol";

/**
 * @title StateZero
 * @dev Base state for all tests with initial setup
 */
abstract contract StateZero is Test {
    // Test addresses
    address internal deployer;
    address internal user1;
    address internal user2;

    // Mock VRF Coordinator configuration
    address internal mockVrfCoordinator;
    bytes32 internal keyHash;
    uint64 internal subscriptionId;

    // Common parameters
    uint256 internal mintPrice;
    uint256 internal maxSupply;

    // Sample metadata
    string[] internal names;
    string[] internal descriptions;
    string[] internal images;
    string[] internal attributes;

    function setUp() public virtual {
        // Setup test addresses
        deployer = makeAddr("deployer");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Setup VRF parameters
        mockVrfCoordinator = makeAddr("vrfCoordinator");
        keyHash = keccak256("keyHash");
        subscriptionId = 1;

        // Setup common parameters
        mintPrice = 0.01 ether;
        maxSupply = 100;

        // Setup sample metadata
        setupSampleMetadata();

        vm.label(deployer, "Deployer");
        vm.label(user1, "User1");
        vm.label(user2, "User2");
        vm.label(mockVrfCoordinator, "VRF Coordinator");
    }

    function setupSampleMetadata() internal {
        names = new string[](3);
        names[0] = "Red SP";
        names[1] = "Green SP";
        names[2] = "Blue SP";

        descriptions = new string[](3);
        descriptions[0] = "A red SP NFT with special powers.";
        descriptions[1] = "A green SP NFT with unique abilities.";
        descriptions[2] = "A blue SP NFT with rare attributes.";

        images = new string[](3);
        images[
            0
        ] = "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI1MDAiIGhlaWdodD0iNTAwIj48cmVjdCB3aWR0aD0iNTAwIiBoZWlnaHQ9IjUwMCIgZmlsbD0iI0ZGMDAwMCIvPjx0ZXh0IHg9IjUwJSIgeT0iNTAlIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMjQiIGZpbGw9IiNmZmYiIHRleHQtYW5jaG9yPSJtaWRkbGUiPlJlZCBTUDwvdGV4dD48L3N2Zz4=";
        images[
            1
        ] = "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI1MDAiIGhlaWdodD0iNTAwIj48cmVjdCB3aWR0aD0iNTAwIiBoZWlnaHQ9IjUwMCIgZmlsbD0iIzAwRkYwMCIvPjx0ZXh0IHg9IjUwJSIgeT0iNTAlIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMjQiIGZpbGw9IiMwMDAiIHRleHQtYW5jaG9yPSJtaWRkbGUiPkdyZWVuIFNQPC90ZXh0Pjwvc3ZnPg==";
        images[
            2
        ] = "data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSI1MDAiIGhlaWdodD0iNTAwIj48cmVjdCB3aWR0aD0iNTAwIiBoZWlnaHQ9IjUwMCIgZmlsbD0iIzAwMDBGRiIvPjx0ZXh0IHg9IjUwJSIgeT0iNTAlIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMjQiIGZpbGw9IiNmZmYiIHRleHQtYW5jaG9yPSJtaWRkbGUiPkJsdWUgU1A8L3RleHQ+PC9zdmc+";

        attributes = new string[](3);
        attributes[
            0
        ] = '[{"trait_type":"Color","value":"Red"},{"trait_type":"Rarity","value":"Common"}]';
        attributes[
            1
        ] = '[{"trait_type":"Color","value":"Green"},{"trait_type":"Rarity","value":"Uncommon"}]';
        attributes[
            2
        ] = '[{"trait_type":"Color","value":"Blue"},{"trait_type":"Rarity","value":"Rare"}]';
    }
}
