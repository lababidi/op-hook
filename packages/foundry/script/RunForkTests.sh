#!/bin/bash

# Script to run OpHook tests with different fork configurations

echo "=== Running OpHook Fork Tests ==="

# 1. Run tests on local anvil/foundry (what you get with yarn chain)
echo "1. Running on local testnet (equivalent to yarn chain):"
forge test --match-contract OpHookForkTest -vv

echo -e "\n=== Fork Testing Options ==="
echo "2. To test against mainnet fork (requires ALCHEMY_API_KEY):"
echo "   forge test --match-contract OpHookForkTest --fork-url https://ethereum-rpc.publicnode.com -vv"

echo -e "\n3. To test against your local yarn chain with deployed contracts:"
echo "   forge test --match-contract OpHookForkTest --fork-url http://localhost:8545 -vv"

echo -e "\n4. To test against Sepolia testnet:"
echo "   forge test --match-contract OpHookForkTest --fork-url https://eth-sepolia.g.alchemy.com/v2/\$ALCHEMY_API_KEY -vvvvv"
echo "   forge test --match-contract OpHookForkTest --fork-url https://unichain-sepolia-rpc.publicnode.com -vvvvv"

echo -e "\nNote: When using fork testing, your tests will have access to:"
echo "- Real deployed contracts (WETH, USDC, etc.)"
echo "- Actual blockchain state and balances"
echo "- Real transaction history and block data"

echo -e "\nFor OpHook specifically, you can:"
echo "- Test with real WETH/USDC tokens"
echo "- Integrate with actual Uniswap V3 pools for price data"
echo "- Test against real Permit2 contracts"
echo "- Verify gas usage on actual network conditions"