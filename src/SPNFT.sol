// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@chainlink/contracts/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

/**
 * @title SPNFT
 * @dev ERC721 token with on-chain metadata and different revealing approaches
 */
contract SPNFT is
    ERC721Enumerable,
    Ownable,
    ReentrancyGuard,
    VRFConsumerBaseV2
{
    using Strings for uint256;

    // Chainlink VRF variables
    VRFCoordinatorV2Interface private immutable vrfCoordinator;
    bytes32 private immutable keyHash;
    uint64 private immutable subscriptionId;
    uint32 private constant CALLBACK_GAS_LIMIT = 100000;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    // NFT variables
    uint256 private mintPrice;
    uint256 private maxSupply;
    uint256 private revealed;
    uint256 private revealBatchSize;
    bool public mintEnabled;
    bool public revealEnabled;

    // Revealing approach
    enum RevealType {
        InCollection,
        SeparateCollection
    }
    RevealType public revealType;
    address public revealedCollectionAddress;

    // NFT metadata arrays
    string[] private names;
    string[] private descriptions;
    string[] private images;
    string[] private attributes;

    // Mapping of tokenId to randomness for metadata
    mapping(uint256 => uint256) public tokenIdToRandomness;

    // Mapping of request ID to token IDs for Chainlink VRF
    mapping(uint256 => uint256[]) private requestIdToTokenIds;

    // Events
    event NFTMinted(address indexed to, uint256 indexed tokenId);
    event NFTRevealed(uint256 indexed tokenId, uint256 indexed randomness);
    event RevealRequested(uint256 indexed requestId, uint256[] tokenIds);
    event RevealTypeSet(RevealType revealType);
    event RevealedCollectionSet(address indexed revealedCollectionAddress);

    /**
     * @dev Constructor to initialize the SPNFT contract
     * @param _name The name of the NFT collection
     * @param _symbol The symbol of the NFT collection
     * @param _mintPrice The price to mint an NFT in wei
     * @param _maxSupply The maximum supply of the NFT collection
     * @param _vrfCoordinator The address of the Chainlink VRF Coordinator
     * @param _keyHash The key hash for the Chainlink VRF
     * @param _subscriptionId The subscription ID for the Chainlink VRF
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _mintPrice,
        uint256 _maxSupply,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subscriptionId
    )
        ERC721(_name, _symbol)
        VRFConsumerBaseV2(_vrfCoordinator)
        Ownable(msg.sender)
    {
        mintPrice = _mintPrice;
        maxSupply = _maxSupply;
        revealBatchSize = 10; // Default batch size for reveals
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;

        // Initialize the NFT with in-collection reveal type by default
        revealType = RevealType.InCollection;
    }

    /**
     * @dev Function to mint an NFT
     * @return tokenId The ID of the minted NFT
     */
    function mint() external payable returns (uint256) {
        require(mintEnabled, "Minting is not enabled");
        require(totalSupply() < maxSupply, "Maximum supply reached");
        require(msg.value >= mintPrice, "Insufficient payment");

        uint256 tokenId = totalSupply() + 1;
        _safeMint(msg.sender, tokenId);

        // Return excess payment if any
        if (msg.value > mintPrice) {
            (bool success, ) = msg.sender.call{value: msg.value - mintPrice}(
                ""
            );
            require(success, "Refund failed");
        }
        emit NFTMinted(msg.sender, tokenId);
        return tokenId;
    }

    /***********************************************/
    /************* REVEAL FUNCTIONS ****************/
    /***********************************************/

    /**
     * @dev Function to set the revealing approach type
     * Per the FAQ, the operator determines the reveal method in advance
     * This must be configured before revealing any SP NFT
     * @param _revealType The type of revealing approach (InCollection or SeparateCollection)
     */
    function setRevealType(RevealType _revealType) external onlyOwner {
        require(!revealEnabled, "Revealing already started");
        revealType = _revealType;
        emit RevealTypeSet(_revealType);
    }

    /**
     * @dev Function to set the address of the revealed collection for the separate collection approach
     * @param _revealedCollectionAddress The address of the revealed collection contract
     */
    function setRevealedCollectionAddress(
        address _revealedCollectionAddress
    ) external onlyOwner {
        require(
            _revealedCollectionAddress != address(0),
            "Invalid Revealed SPNFT address"
        );
        revealedCollectionAddress = _revealedCollectionAddress;
        emit RevealedCollectionSet(_revealedCollectionAddress);
    }

    /**
     * @dev Function for an end user to request the reveal of their token
     * @param tokenId The ID of the token to reveal
     */
    // slither-disable-next-line reentrancy-eth,reentrancy-events,reentrancy-no-eth
    function requestReveal(uint256 tokenId) external nonReentrant {
        require(revealEnabled, "Revealing is not enabled");
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender, "Not the owner of this token");
        require(tokenIdToRandomness[tokenId] == 0, "Token already revealed");

        // Create an array with just this token ID

        uint256[] memory tokenIdsToReveal = new uint256[](1);
        tokenIdsToReveal[0] = tokenId;

        // Request randomness from Chainlink VRF
        uint256 requestId = vrfCoordinator.requestRandomWords(
            keyHash,
            subscriptionId,
            REQUEST_CONFIRMATIONS,
            CALLBACK_GAS_LIMIT,
            NUM_WORDS
        );

        requestIdToTokenIds[requestId] = tokenIdsToReveal;
        revealed++;

        emit RevealRequested(requestId, tokenIdsToReveal);
    }

    /**
     * @dev Function for the operator to request reveal of multiple tokens (for batch processing)
     * @param tokenIds Array of token IDs to reveal
     */
    // slither-disable-next-line reentrancy-eth,reentrancy-events,reentrancy-no-eth
    function batchRequestReveal(
        uint256[] calldata tokenIds
    ) external onlyOwner nonReentrant {
        require(revealEnabled, "Revealing is not enabled");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(_ownerOf(tokenId) != address(0), "Token does not exist");
            require(
                tokenIdToRandomness[tokenId] == 0,
                "Token already revealed"
            );
        }

        // Request randomness from Chainlink VRF
        uint256 requestId = vrfCoordinator.requestRandomWords(
            keyHash,
            subscriptionId,
            REQUEST_CONFIRMATIONS,
            CALLBACK_GAS_LIMIT,
            NUM_WORDS
        );

        requestIdToTokenIds[requestId] = tokenIds;
        revealed += tokenIds.length;

        emit RevealRequested(requestId, tokenIds);
    }

    /***********************************************/
    /*********** CHAINLINK VRF FUNCTIONS ***********/
    /***********************************************/

    /**
     * @dev Callback function used by Chainlink VRF to deliver randomness
     * Per the FAQ, VRF is used during the revealing phase to randomly map metadata to token IDs
     * @param requestId The ID of the randomness request
     * @param randomWords The random values returned by the VRF
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        uint256[] memory tokenIds = requestIdToTokenIds[requestId];
        uint256 randomness = randomWords[0];

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];

            // The randomness value is used to randomly select metadata for this token
            // We derive a unique random value for each token from the base randomness
            uint256 tokenRandomness = uint256(
                keccak256(abi.encode(randomness, tokenId))
            );
            tokenIdToRandomness[tokenId] = tokenRandomness;

            // If using separate collection approach, burn the token and mint a new one
            if (
                revealType == RevealType.SeparateCollection &&
                revealedCollectionAddress != address(0)
            ) {
                address tokenOwner = ownerOf(tokenId);
                _burn(tokenId);

                // Call the revealed collection to mint a new token with the same tokenId
                IRevealedSPNFT(revealedCollectionAddress).mintRevealed(
                    tokenOwner,
                    tokenId,
                    tokenRandomness
                );
            }
            // If using in-collection approach, we just keep the tokenRandomness mapping
            // The tokenURI function will use this mapping to generate the revealed metadata

            emit NFTRevealed(tokenId, tokenRandomness);
        }

        delete requestIdToTokenIds[requestId];
    }

    /***********************************************/
    /************* METADATA FUNCTIONS **************/
    /***********************************************/

    /**
     * @dev Function to set the metadata arrays
     * @param _names The array of possible NFT names
     * @param _descriptions The array of possible NFT descriptions
     * @param _images The array of possible NFT images (SVG or base64 encoded)
     * @param _attributes The array of possible NFT attributes in JSON format
     */
    function setMetadata(
        string[] calldata _names,
        string[] calldata _descriptions,
        string[] calldata _images,
        string[] calldata _attributes
    ) external onlyOwner {
        require(
            _names.length == _descriptions.length &&
                _names.length == _images.length &&
                _names.length == _attributes.length,
            "Arrays must have the same length"
        );
        names = _names;
        descriptions = _descriptions;
        images = _images;
        attributes = _attributes;
    }

    /**
     * @dev Function to generate token URI based on token ID
     * @param tokenId The ID of the token
     * @return The URI for the token metadata
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");

        // If token is not revealed yet, return unrevealed metadata
        if (tokenIdToRandomness[tokenId] == 0) {
            return generateUnrevealedMetadata(tokenId);
        }

        // If using in-collection approach or token not yet burned
        if (
            revealType == RevealType.InCollection ||
            _ownerOf(tokenId) != address(0)
        ) {
            return generateRevealedMetadata(tokenId);
        }

        revert("Token URI cannot be determined");
    }

    /**
     * @dev Internal function to generate unrevealed metadata
     * @param tokenId The ID of the token
     * @return The URI for the unrevealed token metadata
     */
    function generateUnrevealedMetadata(
        uint256 tokenId
    ) public pure returns (string memory) {
        string memory name = string(
            abi.encodePacked("Mystery SP NFT #", tokenId.toString())
        );
        string
            memory description = "This SP NFT has not been revealed yet. Wait for the reveal to see what you got!";
        string
            memory image = '<svg xmlns="http://www.w3.org/2000/svg" width="500" height="500"><rect width="500" height="500" fill="#000"/><text x="50%" y="50%" font-family="Arial" font-size="24" fill="#fff" text-anchor="middle">MYSTERY BOX - SP NFT #';
        string memory svgImage = string(
            abi.encodePacked(image, tokenId.toString(), "</text></svg>")
        );
        string memory encodedImage = string(
            abi.encodePacked(
                "data:image/svg+xml;base64,",
                Base64.encode(bytes(svgImage))
            )
        );

        // All unrevealed NFTs share the same simplified metadata as per the FAQ
        string
            memory attributes = '[{"trait_type":"Status","value":"Unrevealed"},{"trait_type":"Type","value":"Mystery Box"}]';

        return _formatTokenURI(name, description, encodedImage, attributes);
    }

    /**
     * @dev Internal function to generate revealed metadata
     * @param tokenId The ID of the token
     * @return The URI for the revealed token metadata
     */
    function generateRevealedMetadata(
        uint256 tokenId
    ) public view returns (string memory) {
        require(names.length > 0, "Metadata not set");

        uint256 randomness = tokenIdToRandomness[tokenId];
        uint256 nameIndex = randomness % names.length;
        uint256 descIndex = (randomness / 100) % descriptions.length;
        uint256 imageIndex = (randomness / 10000) % images.length;
        uint256 attrIndex = (randomness / 1000000) % attributes.length;

        string memory name = string(
            abi.encodePacked(names[nameIndex], " #", tokenId.toString())
        );
        string memory description = descriptions[descIndex];
        string memory image = images[imageIndex];
        string memory attribute = attributes[attrIndex];

        return _formatTokenURI(name, description, image, attribute);
    }

    /**
     * @dev Internal function to format the token URI in the required JSON format
     * According to the FAQ, this should return a complete JSON string per OpenSea metadata standards
     * @param name The name of the token
     * @param description The description of the token
     * @param image The image of the token
     * @param attributes The attributes of the token in JSON format
     * @return The complete token URI with metadata directly included
     */
    function _formatTokenURI(
        string memory name,
        string memory description,
        string memory image,
        string memory attributes
    ) internal pure returns (string memory) {
        // Per the FAQ, we return the complete metadata JSON directly instead of just a URL
        // We still encode it in base64 to make it a valid data URI that can be used by marketplaces
        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name":"',
                        name,
                        '",',
                        '"description":"',
                        description,
                        '",',
                        '"image":"',
                        image,
                        '",',
                        '"attributes":',
                        attributes,
                        "}"
                    )
                )
            )
        );
        return string(abi.encodePacked("data:application/json;base64,", json));
    }

    /***********************************************/
    /************* OPERATOR FUNCTIONS **************/
    /***********************************************/

    /**
     * @dev Function to enable or disable minting
     * @param _mintEnabled Whether minting should be enabled
     */
    function setMintEnabled(bool _mintEnabled) external onlyOwner {
        mintEnabled = _mintEnabled;
    }

    /**
     * @dev Function to enable or disable revealing
     * @param _revealEnabled Whether revealing should be enabled
     */
    function setRevealEnabled(bool _revealEnabled) external onlyOwner {
        revealEnabled = _revealEnabled;
    }

    /**
     * @dev Function to set the mint price
     * @param _mintPrice The new mint price in wei
     */
    function setMintPrice(uint256 _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
    }

    /**
     * @dev Function to set the max supply
     * @param _maxSupply The new max supply
     */
    function setMaxSupply(uint256 _maxSupply) external onlyOwner {
        require(
            _maxSupply >= totalSupply(),
            "New max supply cannot be less than total supply"
        );
        maxSupply = _maxSupply;
    }

    /**
     * @dev Function to set the reveal batch size
     * @param _revealBatchSize The new reveal batch size
     */
    function setRevealBatchSize(uint256 _revealBatchSize) external onlyOwner {
        require(
            _revealBatchSize > 0,
            "Reveal batch size must be greater than 0"
        );
        revealBatchSize = _revealBatchSize;
    }

    /**
     * @dev Function to withdraw funds from the contract
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");
        (bool success, ) = owner().call{value: balance}("");
        require(success, "Transfer to owner failed");
    }
}

/**
 * @title IRevealedSPNFT
 * @dev Interface for the Revealed SP NFT contract
 */
interface IRevealedSPNFT {
    function mintRevealed(
        address to,
        uint256 tokenId,
        uint256 randomness
    ) external;
}
