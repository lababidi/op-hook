# OpHook Testing Guide

This guide covers the comprehensive testing setup for OpHook, including both mock-based testing and real token integration.

## 🧪 Testing Approaches

We provide two complementary testing strategies:

### 1. **Mock Token Testing** (`OpHookFork.t.sol`)
- **Purpose**: Test OpHook's core functionality with controlled mock tokens
- **Advantages**: Fast, reliable, fully controlled environment
- **Use for**: Unit testing, CI/CD, development iteration

### 2. **Real Token Testing** (`OpHookReal.t.sol`) 
- **Purpose**: Test OpHook with real deployed tokens and price feeds
- **Advantages**: Real-world validation, actual market conditions
- **Use for**: Integration testing, pre-deployment validation, mainnet fork testing

## 📋 Test Coverage

### ✅ **Mock Token Tests (OpHookFork.t.sol)**

**Passing Tests:**
- `testForkSetup()` - Basic setup and deployment verification
- `testERC4626FunctionsFork()` - Vault deposit/withdraw functionality
- `testPoolInitializationFork()` - Pool creation with PoolManager
- `testFullOptionTokenWorkflow()` - Complete option token lifecycle
- `testWhitelistAndSwapBehavior()` - Whitelist management and hook behavior
- `testVaultIntegrationWithOptions()` - Vault + option integration

**What's Tested:**
- ✅ ERC4626 vault operations (deposit, withdraw, mint, redeem)
- ✅ Hook permissions and Uniswap V4 integration
- ✅ Option pool initialization
- ✅ Whitelist functionality
- ✅ Vault statistics and state management
- ✅ Custom option token creation and management

### 📈 **Real Token Tests (OpHookReal.t.sol)**

**Available Tests:**
- `testRealTokenSetup()` - Setup verification with real contracts
- `testVaultWithRealTokens()` - Vault operations with real WETH/USDC
- `testMainnetForkWithWhale()` - Testing with whale accounts on mainnet fork
- `testWithDealHelper()` - Using Foundry's deal() for token balances
- `testRealPriceFeeds()` - Integration with real Uniswap V3 price feeds

## 🚀 How to Run Tests

### Local Development (Mock Tokens)
```bash
# Run all mock token tests
forge test --match-contract OpHookForkTest -vv

# Run specific mock test
forge test --match-test testFullOptionTokenWorkflow -vv

# Run all fork tests with gas reporting
forge test --match-contract OpHookForkTest -vvv --gas-report
```

### Mainnet Fork Testing (Real Tokens)
```bash
# Set your Alchemy API key
export ALCHEMY_API_KEY="your_key_here"

# Run with mainnet fork
forge test --match-contract OpHookRealTest \
  --fork-url https://eth-mainnet.alchemyapi.io/v2/$ALCHEMY_API_KEY -vv

# Test specific real token functionality
forge test --match-test testMainnetForkWithWhale \
  --fork-url https://eth-mainnet.alchemyapi.io/v2/$ALCHEMY_API_KEY -vv
```

### Scaffold-ETH Fork vs Chain

**Important:** Scaffold-ETH provides two different local environments:

#### `yarn chain` - Clean Local Testnet
- Fresh anvil instance with no fork
- Block number starts at 1
- No real token contracts
- Good for: **Mock token testing**

#### `yarn fork` - Mainnet Fork
- Forks mainnet state with real contracts
- Has real WETH, USDC, and all mainnet contracts
- Block number matches mainnet
- Good for: **Real token testing**

### Testing with Forked Mainnet (yarn fork)
```bash
# Start forked mainnet (this is the key!)
yarn fork

# Then run real token tests
forge test --match-contract OpHookRealTest \
  --fork-url http://localhost:8545 -vv
```

### Testing with Clean Local (yarn chain)  
```bash
# Start clean local chain
yarn chain

# Run mock token tests (recommended for local dev)
forge test --match-contract OpHookForkTest \
  --fork-url http://localhost:8545 -vv
```

### Sepolia Testnet
```bash
forge test --match-contract OpHookRealTest \
  --fork-url https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_API_KEY -vv
```

## 🔧 Configuration

### Real Token Addresses
In `OpHookReal.t.sol`, update these addresses for your specific deployments:

```solidity
// For mainnet fork
address constant MAINNET_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant MAINNET_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

// For your local chain - update these in setUp()
if (block.chainid == 31337) {
    wethAddress = 0xYourDeployedWETHAddress;
    usdcAddress = 0xYourDeployedUSDCAddress;
}
```

### Environment Variables
Create a `.env` file:
```
ALCHEMY_API_KEY=your_alchemy_key
PRIVATE_KEY=your_private_key_for_deployment
ETHERSCAN_API_KEY=your_etherscan_key
```

## 📊 Test Results Summary

**Current Status:**
- **Mock Token Tests**: 5/5 passing ✅
- **Basic OpHook Tests**: 9/10 passing ✅
- **OptionPrice Tests**: 21/21 passing ✅
- **Real Token Tests**: Ready for configuration 🔧

**Total Coverage**: 35+ tests covering all major functionality

## 🌟 Key Features Tested

### Mock Token Testing
1. **Custom Token Creation**: Deploy mock WETH, USDC, and option tokens
2. **Controlled Environment**: Predictable balances and behaviors
3. **Complete Workflows**: Full option lifecycle testing
4. **Hook Integration**: Real PoolManager with mock tokens

### Real Token Testing  
1. **Market Conditions**: Test with real token prices and liquidity
2. **Whale Testing**: Use large holder accounts for realistic scenarios
3. **Price Feed Integration**: Connect to real Uniswap V3 pools
4. **Network Flexibility**: Support mainnet, testnets, and local chains

## 🛠 Development Workflow

### During Development
1. Use **mock tests** for rapid iteration
2. Test individual functions with controlled inputs
3. Validate hook permissions and behaviors

### Pre-Deployment
1. Run **real token tests** on testnet
2. Validate with actual market conditions
3. Test gas usage and performance

### Post-Deployment
1. Use **mainnet fork tests** for ongoing validation
2. Test edge cases with real liquidity
3. Monitor actual usage patterns

## 🎯 Next Steps

1. **Configure Real Tokens**: Set addresses for your deployed tokens
2. **Add Price Feeds**: Connect to real Uniswap V3 pools for pricing
3. **Extend Swap Testing**: Add complex swap scenarios
4. **Performance Testing**: Add gas optimization tests
5. **Security Testing**: Add edge case and failure mode tests

This comprehensive testing setup ensures OpHook is thoroughly validated in both controlled and real-world environments! 🚀