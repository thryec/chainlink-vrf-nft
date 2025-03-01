# SP NFT Project

This project implements a SP NFT (ERC-721) with different metadata revealing approaches. The solution leverages Chainlink for random number generation and allows for two distinct revealing approaches.

## Project Structure

- `SPNFT.sol` - Base SP NFT contract with in-collection revealing support
- `RevealedSPNFT.sol` - Contract for revealed NFTs in the separate collection approach
- `SPToken.sol` - ERC20 token for staking rewards
- `SPNFTStaking.sol` - Contract for staking NFTs to earn rewards

## Features

1. **Two Revealing Approaches:**
   - In-Collection Revealing: The SP NFT and the revealed SP NFT reside in the same ERC-721 contract
   - Separate Collection Revealing: The SP NFT and the revealed SP NFT are stored in separate ERC-721 contracts

2. **On-Chain Metadata:**
   - All metadata are stored on-chain
   - Metadata is generated on the fly within the tokenURI() function

3. **Chainlink Integration:**
   - Uses Chainlink VRF for random number generation
   - Selects corresponding metadata based on the random number

4. **Purchase and Return:**
   - Buy SP NFT with Ether
   - Returns excessive funds if the final mint price is lower than the purchase price

5. **Staking and Claim (Bonus):**
   - Stake revealed SP NFTs to earn 5% APY in ERC20 tokens
   - Claim rewards at any time

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- An Ethereum wallet with Sepolia ETH for deployment
- A Chainlink VRF subscription on Sepolia

## Setup

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd sp-nft-project
   ```

2. Install dependencies:
   ```bash
   forge install
   ```

3. Set up environment variables:
   - Create a `.env` file with the following variables:
     ```
     PRIVATE_KEY=your_private_key
     SEPOLIA_RPC_URL=your_sepolia_rpc_url
     ETHERSCAN_API_KEY=your_etherscan_api_key
     ```

4. Configure your Chainlink VRF:
   - Go to [Chainlink VRF Subscription Manager](https://vrf.chain.link/) and create a subscription
   - Fund your subscription with LINK tokens
   - Add the consumer contract address (after deployment)
   - Update the `SUBSCRIPTION_ID` in the deployment script

## Deployment

1. Deploy the contracts to Sepolia:
   ```bash
   source .env
   forge script script/Deploy.s.sol:DeployScript --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
   ```

2. After deployment, add your SPNFT contract address as a consumer in your Chainlink VRF subscription.

## Usage

### Minting an NFT

To mint an NFT, call the `mint` function on the SPNFT contract with the required ETH value.

### Setting Reveal Type

As the contract owner, you can set the reveal type before revealing starts:
1. Call `setRevealType(0)` for in-collection revealing
2. Call `setRevealType(1)` for separate collection revealing (make sure you've set the revealed collection address)

### Requesting Reveal

1. As the operator, enable revealing by calling `setRevealEnabled(true)`
2. End users can call `requestReveal(tokenId)` to reveal their own tokens
3. Alternatively, the operator can call `batchRequestReveal([tokenIds])` to reveal multiple tokens at once
4. Once the Chainlink VRF callback is fulfilled, the tokens will be revealed with randomly assigned metadata

### Staking NFTs

1. Approve the staking contract to transfer your revealed NFT
2. Call `stake(tokenId)` on the staking contract
3. To claim rewards without unstaking, call `claimRewards(tokenId)`
4. To unstake and claim rewards, call `unstake(tokenId)`

## Contract Addresses (Sepolia)

- SPNFT: [contract_address]
- RevealedSPNFT: [contract_address]
- SPToken: [contract_address]
- SPNFTStaking: [contract_address]

## Security Considerations

- All contracts use OpenZeppelin's secure implementations where possible
- ReentrancyGuard is used to prevent reentrancy attacks in critical functions
- Ownership controls ensure only authorized addresses can perform sensitive operations
- Input validation ensures data integrity

## Gas Optimizations

- Batch processing for token reveals
- Efficient storage usage
- Limited array operations
- Use of mapping for O(1) lookups