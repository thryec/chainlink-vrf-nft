// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../src/SPNFT.sol";

/**
 * @title SPNFTWithExposedVRF
 * @dev Test contract that extends SPNFT and exposes the VRF callback function
 * This allows tests to directly call the otherwise internal function
 */
contract SPNFTWithExposedVRF is SPNFT {
    mapping(uint256 => uint256) private tokenIdToRandomness;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _mintPrice,
        uint256 _maxSupply,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId
    )
        SPNFT(
            _name,
            _symbol,
            _mintPrice,
            _maxSupply,
            _vrfCoordinator,
            _keyHash,
            _subscriptionId
        )
    {}

    /**
     * @dev Exposes the internal fulfillRandomWords function for testing
     */
    function testFulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) external {
        fulfillRandomWords(requestId, randomWords);
    }

    /**
     * @dev Helper function to check if a token is revealed
     */
    function isTokenRevealed(uint256 tokenId) external view returns (bool) {
        return tokenIdToRandomness[tokenId] != 0;
    }

    /**
     * @dev Helper function to get the randomness value for a token
     */
    function getTokenRandomness(
        uint256 tokenId
    ) external view returns (uint256) {
        return tokenIdToRandomness[tokenId];
    }
}

/**
 * @title VRFMockTest
 * @dev Test contract for the VRF mock functionality
 */
contract VRFMockTest {
    function testVRFExposed() public {
        address vrfCoordinator = address(1);
        bytes32 keyHash = keccak256("keyHash");
        uint64 subscriptionId = 1;

        SPNFTWithExposedVRF spnft = new SPNFTWithExposedVRF(
            "Test NFT",
            "TEST",
            0.01 ether,
            100,
            vrfCoordinator,
            keyHash,
            subscriptionId
        );

        // This test simply verifies that the contract compiles
        // The actual VRF testing would be done in other test files using this helper
    }
}
