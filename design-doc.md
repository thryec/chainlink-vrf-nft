# SP NFT Design Document

## Overview

This document provides a detailed explanation of the SP NFT project architecture, including each contract's role, how they integrate with each other, and how they implement the required functionality.

## Architecture

The SP NFT project consists of the following components:

```
                              +----------------+
                              |                |
                              |      SPNFT     |
                              |                |
                              +-------+--------+
                                      |
                           Reveals to |
                                      |
             +-----------------------++-----------------------+
             |                                               |
+------------v-----------+                     +-------------v----------+
|                        |                     |                        |
| In-Collection Revealed |                     | RevealedSPNFT          |
| (Same Contract)        |                     | (Separate Contract)    |
|                        |                     |                        |
+------------+-----------+                     +-------------+----------+
             |                                               |
             |                  Staking                      |
             |                                               |
             v                                               v
       +-----+----------------------------------------+------+
       |                                                     |
       |                  SPNFTStaking                       |
       |                                                     |
       +---------------------------+-------------------------+
                                   |
                                   | Rewards
                                   |
                                   v
                          +--------+--------+
                          |                 |
                          |    SPToken      |
                          |                 |
                          +-----------------+
```

## Contracts

### 1. SPNFT.sol

**Role**: Primary contract for the SP NFT collection with dual-mode reveal support.

**Integration Points**:
- Integrates with Chainlink VRF for random number generation
- Integrates with RevealedSPNFT for separate collection revealing
- Serves as the entry point for NFT minting and revealing

**Functionality**:
- **ERC-721 Implementation**: Standard NFT functionality with enumeration and metadata extensions
- **Minting**: Allows users to mint NFTs with ETH and refunds excess payment
- **Revealing Approaches**: Supports both in-collection and separate collection revealing
- **On-Chain Metadata**: Stores and generates metadata on-chain
- **Chainlink VRF Integration**: Uses Chainlink for secure randomness to determine NFT traits
- **Reveal Status Tracking**: Tracks whether a token has been revealed via the `isRevealed` function

**Key Functions**:
- `mint()`: Allows users to mint NFTs with ETH payment
- `setRevealType(RevealType)`: Sets the revealing approach (in-collection or separate)
- `requestReveal(tokenId)`: Allows end users to initiate the reveal process for a specific token
- `batchRequestReveal(tokenIds)`: Allows operators to request reveals for multiple tokens
- `fulfillRandomWords()`: Callback from Chainlink VRF that processes randomness
- `tokenURI()`: Generates metadata URI on the fly based on token ID and reveal status
- `isRevealed(tokenId)`: Checks if a token has been revealed

### 2. RevealedSPNFT.sol

**Role**: Contract for revealed NFTs in the separate collection approach.

**Integration Points**:
- Integrated with SPNFT as the target for separate collection reveals
- Can be staked in the SPNFTStaking contract

**Functionality**:
- **ERC-721 Implementation**: Standard NFT functionality for revealed NFTs
- **Permissioned Minting**: Only allows the original SPNFT contract to mint
- **On-Chain Metadata**: Stores and generates metadata on-chain

**Key Functions**:
- `mintRevealed()`: Mints a new revealed NFT, called by the SPNFT contract
- `tokenURI()`: Generates metadata URI on the fly based on token ID and randomness

### 3. SPToken.sol

**Role**: ERC-20 token used for staking rewards.

**Integration Points**:
- Integrated with SPNFTStaking to provide rewards

**Functionality**:
- **ERC-20 Implementation**: Standard token functionality
- **Permissioned Minting**: Only allows the staking contract to mint tokens

**Key Functions**:
- `mint()`: Mints tokens to a user, called by the staking contract
- `burn()`: Allows users to burn their tokens

### 4. SPNFTStaking.sol

**Role**: Enables users to stake their revealed NFTs and earn rewards.

**Integration Points**:
- Integrates with both SPNFT (for in-collection revealed NFTs) and RevealedSPNFT (for separate collection revealed NFTs)
- Integrates with SPToken to distribute rewards

**Functionality**:
- **Unified Staking Mechanism**: Allows users to stake NFTs from either collection
- **Reveal Verification**: Ensures only revealed tokens can be staked
- **Reward Calculation**: Implements 5% APY reward calculation
- **Claiming System**: Allows users to claim rewards without unstaking

**Key Functions**:
- `stake(NFTType, tokenId)`: Stakes an NFT from either collection and begins earning rewards
- `unstake(NFTType, tokenId)`: Unstakes an NFT and claims rewards
- `claimRewards(NFTType, tokenId)`: Claims rewards without unstaking
- `calculateRewards(NFTType, tokenId)`: Calculates pending rewards for a staked NFT
- `getAllStakedTokens(owner)`: Returns all tokens staked by an owner across both collections
- `getTotalPendingRewards(owner)`: Calculates total rewards pending across all staked tokens

## Technical Design Decisions

### 1. On-Chain Metadata

All metadata is stored on-chain and generated on the fly through the `tokenURI()` function as specified in the project requirements. This approach has several advantages:

- **No External Dependencies**: The metadata doesn't rely on external servers
- **Permanence**: The metadata will exist as long as the blockchain exists
- **Transparency**: Users can verify the metadata directly on-chain
- **Mystery Box Concept**: Before reveal, all NFTs share the same simplified metadata (like a mystery box)

The metadata follows OpenSea's metadata standard format, returning a complete JSON object with name, description, image, and attributes. After reveal, each token's metadata is uniquely determined based on the randomness from Chainlink VRF.

### 2. Revealing Approaches

The system supports two revealing approaches:

**In-Collection Revealing**:
- The SP NFT and the revealed SP NFT reside in the same contract
- When revealed, the metadata for the token is updated based on randomness
- Tokens remain in the original collection but with new metadata
- After revealing, tokens can be staked directly

**Separate Collection Revealing**:
- The SP NFT and revealed SP NFT are in separate contracts
- When revealing, the original NFT is burned and a new one is minted in the revealed collection
- Tokens are transferred to a dedicated collection for revealed NFTs
- Tokens in the revealed collection can be staked without additional checks

Both approaches are designed with reusability in mind, allowing for potential application in other NFT projects.

### 3. Chainlink VRF Integration

Chainlink VRF is used during the revealing phase to provide verifiable randomness for determining NFT traits:

- **User-Initiated Reveals**: End users can request reveals for their own tokens
- **Operator Batch Reveals**: Operators can request reveals for multiple tokens
- **Secure Randomness**: Prevents manipulation of NFT rarities
- **Verifiability**: Users can verify the randomness was generated fairly

The VRF callback `fulfillRandomWords()` is used to:
1. Store randomness for each revealed token
2. Either update metadata (in-collection) or burn and mint tokens (separate collection)

### 4. Staking Mechanism

The staking mechanism uses a unified approach to handle both types of revealed NFTs:

- **Type-Based Staking**: Uses an enum to identify which collection a token belongs to
- **Reveal Verification**: Checks that tokens from the original collection are revealed before staking
- **Consistent Rewards**: Same APY (5%) for both token types
- **Flexible Architecture**: Easy to add new token types or modify staking parameters

### 5. Gas Optimization

Several gas optimization techniques are employed:

- **Unified Staking Logic**: Single stake/unstake functions with type parameter
- **Efficient Storage**: Using structured data types to minimize storage costs
- **Minimal Redundancy**: Avoiding duplicate storage of data
- **Optimized Collections**: Using arrays and mappings for efficient token tracking

## Security Considerations

1. **Access Control**: Only authorized addresses can perform sensitive operations
2. **Reentrancy Protection**: Using ReentrancyGuard for functions that transfer assets
3. **Input Validation**: Checking inputs for validity before processing
4. **Secure Randomness**: Using Chainlink VRF for unpredictable and verifiable randomness
5. **Reveal Verification**: Ensuring only revealed tokens can be staked
6. **Permission Checks**: Verifying ownership and permissions for all operations

## Future Considerations

1. **Multiple Reward Tokens**: Support for different types of reward tokens
2. **Tiered Staking Rewards**: Different reward rates based on NFT rarity
3. **Governance Mechanisms**: Community governance for important parameters
4. **Marketplace Integration**: Direct integration with NFT marketplaces
5. **Additional Reveal Approaches**: Support for new revealing methodologies