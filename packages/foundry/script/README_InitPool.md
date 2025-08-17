# Pool Initialization Script

This script initializes a new Uniswap V4 pool on the Sepolia testnet using your custom hook contract.

## Prerequisites

1. **Environment Setup**: Make sure you have the following environment variables set:
   ```bash
   export ALCHEMY_API_KEY="your_alchemy_api_key"
   export PRIVATE_KEY="your_private_key"
   ```

2. **Hook Contract**: Your hook contract must be deployed and verified on Sepolia testnet.

3. **Token Contracts**: The tokens you want to create a pool for must be deployed on Sepolia testnet.

## Configuration

Before running the script, you need to update the configuration constants in `InitPool.sol`:

### 1. Hook Contract Address
```solidity
address constant HOOK_ADDRESS = address(0x1234567890123456789012345678901234567890);
```
Replace with your deployed hook contract address.

### 2. Token Addresses
```solidity
address constant TOKEN0_ADDRESS = address(0x1111111111111111111111111111111111111111);
address constant TOKEN1_ADDRESS = address(0x2222222222222222222222222222222222222222);
```
Replace with your token addresses. **Important**: Token0 must have a lower address than Token1 (sorted numerically).

### 3. Pool Configuration
```solidity
uint24 constant FEE = 3000; // 0.3% fee tier
int24 constant TICK_SPACING = 60; // Standard for 0.3% fee tier
```
Common fee tiers:
- `500` (0.05%) with `tickSpacing = 10`
- `3000` (0.3%) with `tickSpacing = 60`
- `10000` (1%) with `tickSpacing = 200`

### 4. Initial Price
```solidity
uint160 constant INITIAL_SQRT_PRICE_X96 = 79228162514264337593543950336; // 2^96 (1:1 price)
```
This sets the initial price ratio. The default is 1:1. You can use the helper functions to calculate different prices:
- `calculateSqrtPriceX96(priceRatio)` - Calculate sqrtPriceX96 for a given price ratio
- `getTickForPrice(priceRatio)` - Get the tick for a given price ratio

### 5. PoolManager Address
```solidity
address constant POOL_MANAGER_ADDRESS = address(0x8c8ec1e9577C4b4C4C4C4c4C4c4c4c4C4c4C4C4C4C);
```
This should be the correct PoolManager address for Sepolia testnet. Verify this address before running.

## Usage

### 1. Compile the Script
```bash
cd packages/foundry
forge build
```

### 2. Run the Script
```bash
# Basic execution
forge script script/InitPool.sol --rpc-url sepolia --broadcast

# With verification (if you want to verify the transaction)
forge script script/InitPool.sol --rpc-url sepolia --broadcast --verify

# With specific private key
forge script script/InitPool.sol --rpc-url sepolia --broadcast --private-key $PRIVATE_KEY
```

### 3. Verify Deployment
The script will output:
- Pool ID
- Initial tick
- Verification data (sqrtPriceX96, currentTick, protocolFee, lpFee)

## Example Output
```
Starting pool initialization on Sepolia...
Deployer: 0x1234567890123456789012345678901234567890
Hook address: 0xabcdefabcdefabcdefabcdefabcdefabcdefabcd
Token0: 0x1111111111111111111111111111111111111111
Token1: 0x2222222222222222222222222222222222222222
Fee: 3000
Tick spacing: 60
Initial sqrtPriceX96: 79228162514264337593543950336
Pool ID: 0x1234567890123456789012345678901234567890123456789012345678901234
Initializing pool...
Pool initialized successfully!
Initial tick: 0
Verification:
  sqrtPriceX96: 79228162514264337593543950336
  currentTick: 0
  protocolFee: 0
  lpFee: 3000
Pool initialization completed successfully!
```

## Helper Functions

The script includes several helper functions for price calculations:

### Calculate sqrtPriceX96 for a Price Ratio
```solidity
uint160 sqrtPriceX96 = calculateSqrtPriceX96(1e18); // 1:1 ratio
uint160 sqrtPriceX96 = calculateSqrtPriceX96(2e18); // 2:1 ratio (token1 is twice as expensive)
uint160 sqrtPriceX96 = calculateSqrtPriceX96(5e17); // 0.5:1 ratio (token1 is half as expensive)
```

### Get Tick for a Price Ratio
```solidity
int24 tick = getTickForPrice(1e18); // Tick for 1:1 ratio
int24 tick = getTickForPrice(2e18); // Tick for 2:1 ratio
```

## Troubleshooting

### Common Issues

1. **"Hook address cannot be zero"**
   - Make sure you've set the correct hook contract address

2. **"Tokens must be sorted numerically"**
   - Ensure Token0 address < Token1 address

3. **"Hook contract does not exist"**
   - Verify your hook contract is deployed and the address is correct

4. **"PoolManager address not found"**
   - Check if the PoolManager address is correct for Sepolia

5. **Transaction fails with "HookAddressNotValid"**
   - Your hook contract must implement the required IHooks interface
   - Make sure the hook contract is properly deployed and verified

### Gas Issues
If you encounter gas issues, you can:
1. Increase gas limit: `--gas-limit 5000000`
2. Use a higher gas price: `--gas-price 20000000000`

### Network Issues
If you have RPC issues:
1. Check your Alchemy API key
2. Try a different RPC endpoint
3. Ensure you have sufficient Sepolia ETH

## Security Notes

1. **Private Key Security**: Never commit your private key to version control
2. **Address Verification**: Always verify contract addresses before running
3. **Test First**: Test on a local network before deploying to Sepolia
4. **Hook Validation**: Ensure your hook contract is properly audited

## Next Steps

After successfully initializing the pool:

1. **Add Liquidity**: Use the Uniswap V4 periphery contracts to add initial liquidity
2. **Test Swaps**: Verify that swaps work correctly with your hook
3. **Monitor**: Keep track of pool activity and hook performance
4. **Upgrade**: Consider upgrading to mainnet when ready

## Resources

- [Uniswap V4 Documentation](https://docs.uniswap.org/contracts/v4/overview)
- [Hook Development Guide](https://docs.uniswap.org/contracts/v4/concepts/hooks)
- [Scaffold-ETH 2 Documentation](https://docs.scaffoldeth.io/)
- [Foundry Book](https://book.getfoundry.sh/)
