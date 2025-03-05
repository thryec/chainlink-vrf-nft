// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23;

import "../src/SPNFT.sol";

contract SPNFTWithExposedVRF is SPNFT {
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

    function testFulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) external {
        fulfillRandomWords(requestId, randomWords);
    }

    function isRevealed(uint256 tokenId) external view returns (bool) {
        return tokenIdToRandomness[tokenId] != 0;
    }

    function getRandomness(uint256 tokenId) external view returns (uint256) {
        return tokenIdToRandomness[tokenId];
    }
}
