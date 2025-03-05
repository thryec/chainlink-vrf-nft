// SPDX-License-Identifier: MIT
pragma solidity >=0.8.23;

// import "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";

/**
 * @title RevealedSPNFT
 * @dev ERC721 token for revealed NFTs in the separate collection approach
 * Per the FAQ, this is used when the reveal type is set to Separate Collection
 * When revealing, the original token is burned and a new token is minted here
 */
contract RevealedSPNFT is ERC721Enumerable, Ownable {
    using Strings for uint256;

    // The address of the original SP NFT contract that can mint new tokens
    address public spnftContract;

    // NFT metadata arrays
    string[] private names;
    string[] private descriptions;
    string[] private images;
    string[] private attributes;

    // Mapping of tokenId to randomness for metadata
    mapping(uint256 => uint256) private tokenIdToRandomness;

    // Events
    event RevealedNFTMinted(
        address indexed to,
        uint256 indexed tokenId,
        uint256 indexed randomness
    );

    /**
     * @dev Constructor to initialize the RevealedSPNFT contract
     * @param _name The name of the NFT collection
     * @param _symbol The symbol of the NFT collection
     */
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) Ownable(msg.sender) {}

    /**
     * @dev Function to set the SP NFT contract address
     * @param _spnftContract The address of the SP NFT contract
     */
    function setSPNFTContract(address _spnftContract) external onlyOwner {
        require(_spnftContract != address(0), "Invalid SPNFT address");
        spnftContract = _spnftContract;
    }

    /**
     * @dev Function to mint a revealed NFT - can only be called by the SP NFT contract
     * @param to The address to mint the token to
     * @param tokenId The ID of the token to mint
     * @param randomness The randomness value for the token's metadata
     */
    function mintRevealed(
        address to,
        uint256 tokenId,
        uint256 randomness
    ) external {
        require(
            msg.sender == spnftContract,
            "Only the SP NFT contract can mint tokens"
        );
        require(_ownerOf(tokenId) == address(0), "Token ID already exists");

        _safeMint(to, tokenId);
        tokenIdToRandomness[tokenId] = randomness;

        emit RevealedNFTMinted(to, tokenId, randomness);
    }

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
     * Per the FAQ, this returns a complete metadata JSON object instead of just a URL
     * @param tokenId The ID of the token
     * @return The URI for the token metadata
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        require(names.length > 0, "Metadata not set");

        // Use the randomness to determine metadata for this token
        uint256 randomness = tokenIdToRandomness[tokenId];
        uint256 nameIndex = randomness % names.length;
        uint256 descIndex = (randomness / 100) % descriptions.length;
        uint256 imageIndex = (randomness / 10000) % images.length;
        uint256 attrIndex = (randomness / 1000000) % attributes.length;

        // Format token metadata with unique traits
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
     * @param name The name of the token
     * @param description The description of the token
     * @param image The image of the token
     * @param attributes The attributes of the token in JSON format
     * @return The complete token URI in base64 encoded JSON format
     */
    function _formatTokenURI(
        string memory name,
        string memory description,
        string memory image,
        string memory attributes
    ) internal pure returns (string memory) {
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
}
