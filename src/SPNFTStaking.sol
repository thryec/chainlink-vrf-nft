// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title ISPToken
 * @dev Interface for the SP Token contract
 */
interface ISPToken {
    function mint(address to, uint256 amount) external;
}

/**
 * @title SPNFTStaking
 * @dev Contract for staking SP NFTs to earn ERC20 rewards
 */
contract SPNFTStaking is ERC721Holder, ReentrancyGuard, Ownable {
    using Math for uint256;

    // Staking constant
    uint256 public constant APY_RATE = 5; // 5% annual percentage yield
    uint256 public constant SECONDS_IN_YEAR = 365 days;

    // ERC721 contract representing the revealed SP NFT
    IERC721 public revealedSPNFT;

    // ERC20 reward token contract
    ISPToken public rewardToken;

    // Staking structure to track staked NFTs
    struct Stake {
        address owner;
        uint256 tokenId;
        uint256 stakedAt;
        uint256 lastClaimAt;
    }

    // Mapping of token ID to Stake struct
    mapping(uint256 => Stake) public stakes;

    // Mapping of owner to staked token IDs
    mapping(address => uint256[]) public stakedTokensByOwner;

    // Events
    event NFTStaked(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 timestamp
    );
    event NFTUnstaked(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 timestamp
    );
    event RewardsClaimed(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 amount,
        uint256 timestamp
    );

    /**
     * @dev Constructor to initialize the SPNFTStaking contract
     * @param _revealedSPNFT The address of the revealed SP NFT contract
     * @param _rewardToken The address of the reward token contract
     */
    constructor(
        address _revealedSPNFT,
        address _rewardToken
    ) Ownable(msg.sender) {
        revealedSPNFT = IERC721(_revealedSPNFT);
        rewardToken = ISPToken(_rewardToken);
    }

    /**
     * @dev Function to calculate the pending rewards for a staked NFT
     * @param tokenId The ID of the staked token
     * @return The amount of rewards pending
     */
    function calculateRewards(uint256 tokenId) public view returns (uint256) {
        Stake memory stake = stakes[tokenId];
        require(stake.owner != address(0), "Token not staked");

        uint256 stakedTime = block.timestamp - stake.lastClaimAt;
        uint256 rewardPerToken = 1 ether; // 1 token as base reward (1e18 wei)

        // Calculate APY based on staked time
        uint256 reward = (rewardPerToken * (APY_RATE) * (stakedTime)) /
            (SECONDS_IN_YEAR * 100); // Divide by 100 for percentage

        return reward;
    }

    /**
     * @dev Function to stake an NFT
     * @param tokenId The ID of the token to stake
     */
    function stake(uint256 tokenId) external nonReentrant {
        require(
            revealedSPNFT.ownerOf(tokenId) == msg.sender,
            "You don't own this NFT"
        );

        // Transfer the NFT to this contract
        revealedSPNFT.safeTransferFrom(msg.sender, address(this), tokenId);

        // Create a new stake
        stakes[tokenId] = Stake({
            owner: msg.sender,
            tokenId: tokenId,
            stakedAt: block.timestamp,
            lastClaimAt: block.timestamp
        });

        // Add token to owner's staked tokens list
        stakedTokensByOwner[msg.sender].push(tokenId);

        emit NFTStaked(msg.sender, tokenId, block.timestamp);
    }

    /**
     * @dev Function to unstake an NFT and claim rewards
     * @param tokenId The ID of the token to unstake
     */
    function unstake(uint256 tokenId) external nonReentrant {
        Stake memory stake = stakes[tokenId];
        require(stake.owner == msg.sender, "You don't own this staked NFT");

        // Calculate rewards
        uint256 rewards = calculateRewards(tokenId);

        // Mint rewards if any
        if (rewards > 0) {
            rewardToken.mint(msg.sender, rewards);
            emit RewardsClaimed(msg.sender, tokenId, rewards, block.timestamp);
        }

        // Transfer the NFT back to the owner
        revealedSPNFT.safeTransferFrom(address(this), msg.sender, tokenId);

        // Remove token from staked tokens
        _removeTokenFromStakedList(msg.sender, tokenId);

        // Delete stake
        delete stakes[tokenId];

        emit NFTUnstaked(msg.sender, tokenId, block.timestamp);
    }

    /**
     * @dev Function to claim rewards without unstaking
     * @param tokenId The ID of the token to claim rewards for
     */
    function claimRewards(uint256 tokenId) external nonReentrant {
        Stake storage stake = stakes[tokenId];
        require(stake.owner == msg.sender, "You don't own this staked NFT");

        // Calculate rewards
        uint256 rewards = calculateRewards(tokenId);
        require(rewards > 0, "No rewards to claim");

        // Update last claim timestamp
        stake.lastClaimAt = block.timestamp;

        // Mint rewards
        rewardToken.mint(msg.sender, rewards);

        emit RewardsClaimed(msg.sender, tokenId, rewards, block.timestamp);
    }

    /**
     * @dev Function to get all staked tokens for an owner
     * @param owner The address of the owner
     * @return An array of token IDs staked by the owner
     */
    function getStakedTokensByOwner(
        address owner
    ) external view returns (uint256[] memory) {
        return stakedTokensByOwner[owner];
    }

    /**
     * @dev Internal function to remove a token from the staked tokens list
     * @param owner The address of the owner
     * @param tokenId The ID of the token to remove
     */
    function _removeTokenFromStakedList(
        address owner,
        uint256 tokenId
    ) internal {
        uint256[] storage stakedTokens = stakedTokensByOwner[owner];
        uint256 length = stakedTokens.length;

        // Find the index of the token ID in the array
        uint256 index = length;
        for (uint256 i = 0; i < length; i++) {
            if (stakedTokens[i] == tokenId) {
                index = i;
                break;
            }
        }

        // If token ID was found in the array
        if (index < length) {
            // Move the last element to the position of the removed element
            stakedTokens[index] = stakedTokens[length - 1];
            // Remove the last element
            stakedTokens.pop();
        }
    }

    /**
     * @dev Function to get total staked tokens by an owner
     * @param owner The address of the owner
     * @return The number of tokens staked by the owner
     */
    function getTotalStakedByOwner(
        address owner
    ) external view returns (uint256) {
        return stakedTokensByOwner[owner].length;
    }

    /**
     * @dev Function to get all pending rewards for an owner across all staked tokens
     * @param owner The address of the owner
     * @return The total amount of rewards pending
     */
    function getTotalPendingRewards(
        address owner
    ) external view returns (uint256) {
        uint256[] memory stakedTokens = stakedTokensByOwner[owner];
        uint256 totalRewards = 0;

        for (uint256 i = 0; i < stakedTokens.length; i++) {
            totalRewards = totalRewards + calculateRewards(stakedTokens[i]);
        }

        return totalRewards;
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
