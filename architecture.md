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
                        | Reveals to
                        |
         +------+-------v---------+------+
         |                                |
+--------v----------+        +------------v-------+
|                   |        |                    |
| In-Collection     |        | RevealedSPNFT      |
| (Same Contract)   |        | (Separate Contract)|
|                   |        |                    |
+---------+---------+        +------------+-------+
          |                               |
          |                               |
          |            Staking            |
          |                               |
          |                               |
          v                               v
    +-----+------+                +-----------------+
    |            |                |                 |
    | SPNFTStaking+--------------->     SPToken     |
    |            |   Rewards     |                 |
    +------------+                +-----------------+
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

**Key Functions**:
- `mint()`: Allows users to mint NFTs with ETH payment
- `setRevealType(RevealType)`: Sets the revealing approach (in-collection or separate)
- `requestReveal()`: Initiates the reveal process by requesting randomness
- `fulfillRandomWords()`: Callback from Chainlink VRF that processes randomness
- `tokenURI()`: Generates metadata URI on the fly based on token ID and reveal status

### 2. RevealedSPNFT.sol

**Role**: Contract for revealed NFTs in the separate collection approach.

**Integration Points**:
- Integrated with SPNFT as the target for separate collection reveals
- Can be integrated with SPNFTStaking for staking functionality

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
- Integrates with RevealedSPNFT to accept NFTs for staking
- Integrates with SPToken to distribute rewards

**Functionality**:
- **Staking Mechanism**: Allows users to lock their NFTs and earn rewards
- **Reward Calculation**: Implements 5% APY reward calculation
- **Claiming System**: Allows users to claim rewards without unstaking

**Key Functions**:
- `stake()`: Stakes an NFT and begins earning rewards
- `unstake()`: Unstakes an NFT and claims rewards
- `claimRewards()`: Claims rewards without unstaking
- `calculateRewards()`: Calculates pending rewards for a staked NFT

## Technical Design Decisions

### 1. On-Chain Metadata

All metadata is stored on-chain and generated on the fly through the `tokenURI()` function as specified in the project requirements. This approach has several advantages:

- **No External Dependencies**: The metadata doesn't rely on external servers
- **Permanence**: The metadata will exist as long as the blockchain exists
- **Transparency**: Users can verify the metadata directly on-chain
- **Mystery Box Concept**: Before reveal, all NFTs share the same simplified metadata (like a mystery box)

The metadata follows OpenSea's metadata standard format, returning a complete JSON object with name, description, image, and attributes. After reveal, each token's metadata is uniquely determined based on the randomness from Chainlink VRF.

### 2. Revealing Approaches

As specified in the FAQ, the system supports two revealing approaches that must be selected by the operator before the reveal process begins:

**In-Collection Revealing**:
- The SP NFT and the revealed SP NFT reside in the same ERC-721 smart contract
- When revealed, the SP NFT's metadata is switched to another set, transforming it into the revealed NFT
- Simpler approach with lower gas costs
- All token history remains in one contract

**Separate Collection Revealing**:
- The SP NFT and revealed SP NFT are stored in separate ERC-721 smart contracts
- When revealing, the system burns the SP NFT, mints a new NFT in the revealed SP NFT smart contract, and transfers it to the end user
- Provides a clear separation between unrevealed and revealed NFTs
- Allows for different functionality in the revealed collection

Both approaches are designed with reusability in mind, allowing for potential application in other NFT projects.

### 3. Chainlink VRF Integration

As explained in the FAQ, Chainlink VRF is used during the revealing phase, not during minting. Its main role is to ensure that when an end user chooses to reveal the metadata for their token, the metadata they receive is randomized and unique:

- **Security**: Prevents manipulation of NFT rarities
- **Verifiability**: Users can verify the randomness was generated fairly
- **Randomization**: Employed to randomly map metadata to a given token ID when the owner initiates the revealing process
- **User-Initiated**: End users can initiate the reveal process for their tokens

The system uses the Chainlink VRF v2 implementation for better scalability and cost-efficiency.

### 4. Staking Mechanism

The staking mechanism allows users to earn rewards by locking their revealed NFTs:

- **Time-Based Rewards**: Rewards are calculated based on time staked
- **Dynamic Claiming**: Users can claim rewards any time without unstaking
- **5% APY**: Rewards are calculated at a fixed 5% annual rate
- **Gas Optimization**: Uses efficient data structures to minimize gas costs

## Gas Optimization Strategies

1. **Batch Processing**: Random number requests and reveals are processed in batches
2. **Efficient Storage**: Using structured data types to minimize storage costs
3. **Minimal Redundancy**: Avoiding duplicate storage of data
4. **Optimized Loops**: Using efficient algorithms for array operations

## Security Considerations

1. **Access Control**: Only authorized addresses can perform sensitive operations
2. **Reentrancy Protection**: Using ReentrancyGuard for functions that transfer assets
3. **Input Validation**: Checking inputs for validity before processing
4. **Safe Math**: Using SafeMath for arithmetic operations to prevent overflows
5. **Secure Randomness**: Using Chainlink VRF for unpredictable and verifiable randomness

## Extensibility

The system is designed to be extensible in several ways:

1. **New Revealing Approaches**: The architecture allows adding new revealing approaches
2. **Metadata Updates**: The metadata can be updated by the contract owner
3. **Staking Parameters**: The staking parameters can be adjusted
4. **Integration with Other Contracts**: The contracts can be integrated with other systems

## Future Considerations

1. **Multiple Reward Tokens**: Support for different types of reward tokens
2. **Tiered Staking Rewards**: Different reward rates based on NFT rarity
3. **Governance Mechanisms**: Community governance for important parameters
4. **Marketplace Integration**: Direct integration with NFT marketplaces

## Implementation Notes

1. All contracts use the latest Solidity version (^0.8.19) to benefit from recent safety features
2. OpenZeppelin contracts are used for standard functionality like ERC-721, ERC-20, and access control
3. Chainlink contracts are used for VRF functionality
4. The code is thoroughly commented to explain complex logic
5. Gas optimization is applied throughout the codebase



## Repository Layout  
project-root/
├── src/
│   ├── SPNFT.sol                      # Base SP NFT contract with two revealing approaches
│   ├── RevealedSPNFT.sol              # Separate collection for revealed NFTs
│   ├── SPToken.sol                    # ERC20 token for staking rewards
│   └── SPNFTStaking.sol               # Staking contract for NFTs
│
├── script/
│   └── Deploy.s.sol                   # Deployment script for all contracts
│
├── test/
│   ├── helpers/
│   │   ├── StateZero.sol                       # Base test state
│   │   ├── SPNFTDeployedState.sol              # SPNFT deployed state
│   │   ├── SPNFTMintedState.sol                # SPNFT minted state
│   │   ├── SPNFTRevealEnabledState.sol         # SPNFT reveal enabled state
│   │   ├── SPNFTInCollectionRevealState.sol    # SPNFT in-collection reveal state
│   │   ├── SPNFTSeparateCollectionRevealState.sol  # SPNFT separate collection state
│   │   ├── StakingDeployedState.sol            # Staking deployed state
│   │   ├── StakingNFTsMintedState.sol          # NFTs minted for staking
│   │   ├── StakingNFTsStakedState.sol          # NFTs staked state
│   │   ├── StakingLongTermState.sol            # Long-term staking state
│   │   └── VRFMock.sol                         # Mock for VRF testing
│   │
│   ├── SPNFT.t.sol                            # Main SPNFT test file
│   └── SPNFTStaking.t.sol                     # Main staking test file
│
├── foundry.toml                      # Foundry configuration
├── README.md                         # Project documentation
├── deploy.sh                         # Deployment script
└── .gitignore                        # Git ignore file