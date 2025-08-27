#!/bin/bash

echo "🧪 OpHook Testing Demonstration"
echo "================================="
echo ""

echo "📋 Test Summary:"
echo "1. Mock Token Tests (OpHookFork.t.sol) - For development and unit testing"
echo "2. Real Token Tests (OpHookReal.t.sol) - For integration and fork testing"
echo ""

echo "🚀 Running Mock Token Tests..."
echo "These work with any environment (yarn chain, yarn fork, or direct forge test)"
echo "----------------------------------------"
forge test --match-contract OpHookForkTest -v

echo ""
echo "🌐 Real Token Test Setup Check..."
echo "These detect the environment and adapt accordingly"
echo "----------------------------------------"
forge test --match-test testRealTokenSetup -v

echo ""
echo "📖 Usage Instructions:"
echo ""
echo "For Development (Mock Tokens):"
echo "  forge test --match-contract OpHookForkTest -vv"
echo ""
echo "For Integration Testing with Real Tokens:"
echo "  1. Start forked mainnet: yarn fork"
echo "  2. Run real tests: forge test --match-contract OpHookRealTest --fork-url http://localhost:8545 -vv"
echo ""
echo "For Direct Mainnet Fork (without yarn):"
echo "  forge test --match-contract OpHookRealTest --fork-url https://eth-mainnet.alchemyapi.io/v2/\$ALCHEMY_API_KEY -vv"
echo ""
echo "✨ The beauty of this setup:"
echo "- Mock tests: Fast, reliable, always work"
echo "- Real tests: Validate against actual market conditions"
echo "- Both approaches complement each other perfectly!"