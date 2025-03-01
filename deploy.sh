#!/bin/bash

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Error: .env file not found"
    echo "Please create a .env file with the following variables:"
    echo "PRIVATE_KEY=your_private_key"
    echo "SEPOLIA_RPC_URL=your_sepolia_rpc_url"
    echo "ETHERSCAN_API_KEY=your_etherscan_api_key"
    exit 1
fi

# Load environment variables
source .env

# Check if variables are set
if [ -z "$PRIVATE_KEY" ] || [ -z "$SEPOLIA_RPC_URL" ] || [ -z "$ETHERSCAN_API_KEY" ]; then
    echo "Error: Missing environment variables"
    echo "Please ensure PRIVATE_KEY, SEPOLIA_RPC_URL, and ETHERSCAN_API_KEY are set in your .env file"
    exit 1
fi

# Install dependencies
echo "Installing dependencies..."
forge install

# Build contracts
echo "Building contracts..."
forge build

# Deploy contracts
echo "Deploying contracts to Sepolia..."
forge script script/Deploy.s.sol:DeployScript --rpc-url $SEPOLIA_RPC_URL --broadcast --verify -vvvv

echo "Deployment complete!"