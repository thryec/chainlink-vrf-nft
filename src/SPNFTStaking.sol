// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../test/SPNFTWithExposedVRF.sol";

/**
 * @title ISPToken
 * @dev Interface for the SP Token contract
 */
interface ISPToken {
    function mint(address to, uint256 amount) external;
}

/**
 * @title SPNFTStaking
 * @dev Contract for staking SP NFTs (both in-collection and separate collection reveals) to earn ERC20 rewards
 */
contract SPNFTStaking is ERC721Holder, ReentrancyGuard, Ownable {
    // Staking constant
    uint256 public constant APY_RATE = 5; // 5% annual percentage yield
    uint256 public constant SECONDS_IN_YEAR = 365 days;

    // ERC721 contracts representing both types of revealed SP NFTs
    IERC721 public originalSPNFT; // For in-collection reveals
    IERC721 public revealedSPNFT; // For separate collection reveals

    // ERC20 reward token contract
    ISPToken public rewardToken;

    // SPNFT contract to access the isRevealed function
    SPNFTWithExposedVRF spnftContract;

    // Enum to identify which NFT collection a token belongs to
    enum NFTType {
        Original,
        Revealed
    }

    // Staking structure to track staked NFTs
    struct Stake {
        address owner;
        uint256 tokenId;
        uint256 stakedAt;
        uint256 lastClaimAt;
        NFTType nftType; // Which collection this token belongs to
    }

    // Mapping of (NFT type => (token ID => Stake))
    mapping(NFTType => mapping(uint256 => Stake)) public stakes;

    // Mapping of owner to staked token IDs for each collection
    mapping(address => uint256[]) private stakedOriginalTokens;
    mapping(address => uint256[]) private stakedRevealedTokens;

    // Events
    event NFTStaked(
        address indexed owner,
        uint256 indexed tokenId,
        NFTType nftType,
        uint256 timestamp
    );
    event NFTUnstaked(
        address indexed owner,
        uint256 indexed tokenId,
        NFTType nftType,
        uint256 timestamp
    );
    event RewardsClaimed(
        address indexed owner,
        uint256 indexed tokenId,
        NFTType nftType,
        uint256 amount,
        uint256 timestamp
    );

    /**
     * @dev Constructor to initialize the SPNFTStaking contract
     * @param _originalSPNFT The address of the original SP NFT contract (for in-collection reveals)
     * @param _revealedSPNFT The address of the revealed SP NFT contract (for separate collection reveals)
     * @param _rewardToken The address of the reward token contract
     */
    constructor(
        address _originalSPNFT,
        address _revealedSPNFT,
        address _rewardToken
    ) Ownable(msg.sender) {
        originalSPNFT = IERC721(_originalSPNFT);
        revealedSPNFT = IERC721(_revealedSPNFT);
        rewardToken = ISPToken(_rewardToken);

        spnftContract = SPNFTWithExposedVRF(address(originalSPNFT));
    }

    /**
     * @dev Function to stake an NFT from either collection
     * @param nftType The type of NFT (Original or Revealed)
     * @param tokenId The ID of the token to stake
     */
    function stake(NFTType nftType, uint256 tokenId) external nonReentrant {
        // Determine which NFT contract to use
        IERC721 nftContract = nftType == NFTType.Original
            ? originalSPNFT
            : revealedSPNFT;

        // Check ownership
        require(
            nftContract.ownerOf(tokenId) == msg.sender,
            "You don't own this NFT"
        );

        // Check if token is revealed by calling the isRevealed function on the originalSPNFT
        if (nftType == NFTType.Original) {
            // We need to cast to access the isRevealed function
            require(
                spnftContract.isRevealed(tokenId),
                "Token must be revealed before staking"
            );
        }

        // For revealed collection, the token is already revealed by definition

        // Transfer NFT to contract
        nftContract.safeTransferFrom(msg.sender, address(this), tokenId);

        // Create stake
        stakes[nftType][tokenId] = Stake({
            owner: msg.sender,
            tokenId: tokenId,
            stakedAt: block.timestamp,
            lastClaimAt: block.timestamp,
            nftType: nftType
        });

        // Add to the owner's staked tokens list
        if (nftType == NFTType.Original) {
            stakedOriginalTokens[msg.sender].push(tokenId);
        } else {
            stakedRevealedTokens[msg.sender].push(tokenId);
        }

        emit NFTStaked(msg.sender, tokenId, nftType, block.timestamp);
    }

    /**
     * @dev Function to calculate pending rewards for a staked NFT
     * @param nftType The type of NFT (Original or Revealed)
     * @param tokenId The ID of the staked token
     * @return The amount of rewards pending
     */
    function calculateRewards(
        NFTType nftType,
        uint256 tokenId
    ) public view returns (uint256) {
        Stake memory stakeInfo = stakes[nftType][tokenId];
        require(stakeInfo.owner != address(0), "Token not staked");

        uint256 stakedTime = block.timestamp - stakeInfo.lastClaimAt;
        uint256 rewardPerToken = 1 ether; // 1 token as base reward (1e18 wei)

        // Calculate APY based on staked time
        uint256 reward = (rewardPerToken * APY_RATE * stakedTime) /
            (SECONDS_IN_YEAR * 100); // Divide by 100 for percentage

        return reward;
    }

    /**
     * @dev Function to unstake an NFT and claim rewards
     * @param nftType The type of NFT (Original or Revealed)
     * @param tokenId The ID of the token to unstake
     */
    function unstake(NFTType nftType, uint256 tokenId) external nonReentrant {
        Stake memory stakeInfo = stakes[nftType][tokenId];
        require(stakeInfo.owner == msg.sender, "You don't own this staked NFT");

        // Calculate rewards
        uint256 rewards = calculateRewards(nftType, tokenId);

        // Mint rewards if any
        if (rewards > 0) {
            rewardToken.mint(msg.sender, rewards);
            emit RewardsClaimed(
                msg.sender,
                tokenId,
                nftType,
                rewards,
                block.timestamp
            );
        }

        // Determine which NFT contract to use
        IERC721 nftContract = nftType == NFTType.Original
            ? originalSPNFT
            : revealedSPNFT;

        // Transfer the NFT back to the owner
        nftContract.safeTransferFrom(address(this), msg.sender, tokenId);

        // Remove token from staked tokens list
        if (nftType == NFTType.Original) {
            _removeTokenFromStakedList(
                msg.sender,
                tokenId,
                stakedOriginalTokens
            );
        } else {
            _removeTokenFromStakedList(
                msg.sender,
                tokenId,
                stakedRevealedTokens
            );
        }

        // Delete stake
        delete stakes[nftType][tokenId];

        emit NFTUnstaked(msg.sender, tokenId, nftType, block.timestamp);
    }

    /**
     * @dev Function to claim rewards without unstaking
     * @param nftType The type of NFT (Original or Revealed)
     * @param tokenId The ID of the token to claim rewards for
     */
    function claimRewards(
        NFTType nftType,
        uint256 tokenId
    ) external nonReentrant {
        Stake storage stakeInfo = stakes[nftType][tokenId];
        require(stakeInfo.owner == msg.sender, "You don't own this staked NFT");

        // Calculate rewards
        uint256 rewards = calculateRewards(nftType, tokenId);
        require(rewards > 0, "No rewards to claim");

        // Update last claim timestamp
        stakeInfo.lastClaimAt = block.timestamp;

        // Mint rewards
        rewardToken.mint(msg.sender, rewards);

        emit RewardsClaimed(
            msg.sender,
            tokenId,
            nftType,
            rewards,
            block.timestamp
        );
    }

    /**
     * @dev Function to get staked tokens from the original collection for an owner
     * @param owner The address of the owner
     * @return An array of token IDs staked by the owner
     */
    function getStakedOriginalTokens(
        address owner
    ) external view returns (uint256[] memory) {
        return stakedOriginalTokens[owner];
    }

    /**
     * @dev Function to get staked tokens from the revealed collection for an owner
     * @param owner The address of the owner
     * @return An array of token IDs staked by the owner
     */
    function getStakedRevealedTokens(
        address owner
    ) external view returns (uint256[] memory) {
        return stakedRevealedTokens[owner];
    }

    /**
     * @dev Function to get all staked tokens for an owner across both collections
     * @param owner The address of the owner
     * @return originalTokens The token IDs from original collection
     * @return revealedTokens The token IDs from revealed collection
     */
    function getAllStakedTokens(
        address owner
    )
        external
        view
        returns (
            uint256[] memory originalTokens,
            uint256[] memory revealedTokens
        )
    {
        return (stakedOriginalTokens[owner], stakedRevealedTokens[owner]);
    }

    /**
     * @dev Internal function to remove a token from the staked tokens list
     * @param owner The address of the owner
     * @param tokenId The ID of the token to remove
     * @param stakedTokens The storage array of staked tokens to modify
     */
    function _removeTokenFromStakedList(
        address owner,
        uint256 tokenId,
        mapping(address => uint256[]) storage stakedTokens
    ) internal {
        uint256[] storage tokens = stakedTokens[owner];
        uint256 length = tokens.length;

        // Find the index of the token ID in the array
        uint256 index = length;
        for (uint256 i = 0; i < length; i++) {
            if (tokens[i] == tokenId) {
                index = i;
                break;
            }
        }

        // If token ID was found in the array
        if (index < length) {
            // Move the last element to the position of the removed element
            tokens[index] = tokens[length - 1];
            // Remove the last element
            tokens.pop();
        }
    }

    /**
     * @dev Function to get total staked tokens by an owner across both collections
     * @param owner The address of the owner
     * @return The number of tokens staked by the owner
     */
    function getTotalStakedByOwner(
        address owner
    ) external view returns (uint256) {
        return
            stakedOriginalTokens[owner].length +
            stakedRevealedTokens[owner].length;
    }

    /**
     * @dev Function to get all pending rewards for an owner across all staked tokens
     * @param owner The address of the owner
     * @return The total amount of rewards pending
     */
    function getTotalPendingRewards(
        address owner
    ) external view returns (uint256) {
        uint256 totalRewards = 0;

        // Calculate rewards for original collection tokens
        uint256[] memory originalTokens = stakedOriginalTokens[owner];
        for (uint256 i = 0; i < originalTokens.length; i++) {
            totalRewards =
                totalRewards +
                calculateRewards(NFTType.Original, originalTokens[i]);
        }

        // Calculate rewards for revealed collection tokens
        uint256[] memory revealedTokens = stakedRevealedTokens[owner];
        for (uint256 i = 0; i < revealedTokens.length; i++) {
            totalRewards =
                totalRewards +
                calculateRewards(NFTType.Revealed, revealedTokens[i]);
        }

        return totalRewards;
    }

    /**
     * @dev Function to update the original SP NFT contract
     * @param _originalSPNFT The address of the new original SP NFT contract
     */
    function setOriginalSPNFT(address _originalSPNFT) external onlyOwner {
        originalSPNFT = IERC721(_originalSPNFT);
    }

    /**
     * @dev Function to update the revealed SP NFT contract
     * @param _revealedSPNFT The address of the new revealed SP NFT contract
     */
    function setRevealedSPNFT(address _revealedSPNFT) external onlyOwner {
        revealedSPNFT = IERC721(_revealedSPNFT);
    }

    /**
     * @dev Function to update the reward token contract
     * @param _rewardToken The address of the new reward token contract
     */
    function setRewardToken(address _rewardToken) external onlyOwner {
        rewardToken = ISPToken(_rewardToken);
    }
}
