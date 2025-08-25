# OptionPoolVault - ERC4626 Vault Implementation

## Overview

The `OptionPoolVault` is a comprehensive ERC4626-compliant tokenized vault implementation designed for managing option pool assets. It provides a secure, flexible, and feature-rich foundation for building DeFi vaults with option pool integration.

## Features

### Core ERC4626 Compliance
- **Standard Compliance**: Full implementation of the ERC4626 "Tokenized Vault Standard"
- **Deposit/Withdraw**: Standard deposit and withdrawal functionality
- **Mint/Redeem**: Share-based minting and redemption
- **Conversion Functions**: Asset-to-share and share-to-asset conversion
- **Preview Functions**: Pre-execution calculation of amounts

### Security Features
- **Reentrancy Protection**: `nonReentrant` modifier on all state-changing functions
- **Pausable Operations**: Emergency pause functionality for deposits, withdrawals, or all operations
- **Access Control**: Owner-only functions for critical operations
- **Input Validation**: Comprehensive parameter validation

### Fee Management
- **Configurable Fee Rate**: Fee rate in basis points (0.01% increments)
- **Maximum Fee Cap**: 10% maximum fee rate to protect users
- **Fee Recipient**: Configurable fee recipient address
- **Fee Collection**: Automatic fee collection on deposits

### Vault Configuration
- **Minimum Deposit**: Configurable minimum deposit amount
- **Maximum Capacity**: Vault capacity limits
- **Option Pool Integration**: Configurable option pool address
- **Exchange Rate Tracking**: Real-time exchange rate calculation

### Emergency Functions
- **Emergency Withdraw**: Owner can withdraw assets in emergency situations
- **Emergency Pause**: Immediate pause of all operations
- **Selective Pausing**: Pause deposits or withdrawals independently

## Contract Architecture

### Inheritance
```solidity
contract OptionPoolVault is ERC4626, Ownable, ReentrancyGuard, Pausable
```

### Key Components
- **ERC4626**: Base vault functionality from OpenZeppelin
- **Ownable**: Access control for admin functions
- **ReentrancyGuard**: Protection against reentrancy attacks
- **Pausable**: Emergency pause functionality

## Usage

### Deployment

```solidity
// Deploy the vault
OptionPoolVault vault = new OptionPoolVault(
    underlying,        // ERC20 token address
    "Vault Name",      // Vault token name
    "vSYMBOL",         // Vault token symbol
    feeRecipient,      // Fee recipient address
    100,               // Fee rate in basis points (1%)
    optionPool         // Option pool contract address
);
```

### Basic Operations

#### Deposit Assets
```solidity
// Approve tokens first
underlying.approve(address(vault), amount);

// Deposit assets and receive shares
uint256 shares = vault.deposit(amount, receiver);
```

#### Mint Shares
```solidity
// Mint specific number of shares
uint256 assets = vault.mint(shares, receiver);
```

#### Withdraw Assets
```solidity
// Withdraw specific amount of assets
uint256 sharesBurned = vault.withdraw(assets, receiver, owner);
```

#### Redeem Shares
```solidity
// Redeem shares for assets
uint256 assetsReceived = vault.redeem(shares, receiver, owner);
```

### Admin Functions

#### Update Fee Configuration
```solidity
// Update fee recipient
vault.updateFeeRecipient(newRecipient);

// Update fee rate (max 10%)
vault.updateFeeRate(newFeeRate);
```

#### Update Vault Configuration
```solidity
// Update option pool
vault.updateOptionPool(newPool);

// Update minimum deposit
vault.updateMinDeposit(newMinDeposit);

// Update maximum capacity
vault.updateMaxCapacity(newMaxCapacity);
```

#### Pause Operations
```solidity
// Pause all operations
vault.pause();

// Pause only deposits
vault.pauseDeposits();

// Pause only withdrawals
vault.pauseWithdrawals();
```

### View Functions

#### Get Vault Statistics
```solidity
(uint256 totalAssets, uint256 totalShares, uint256 exchangeRate, uint256 utilizationRate) = vault.getVaultStats();
```

#### Check Capacity
```solidity
bool isAtCapacity = vault.isAtCapacity();
```

#### Preview Operations
```solidity
uint256 previewShares = vault.previewDeposit(assets);
uint256 previewAssets = vault.previewMint(shares);
uint256 previewWithdrawShares = vault.previewWithdraw(assets);
uint256 previewRedeemAssets = vault.previewRedeem(shares);
```

## Events

The vault emits the following events:

- `FeeCollected(address indexed from, uint256 amount)`: When fees are collected
- `FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient)`: When fee recipient is updated
- `FeeRateUpdated(uint256 oldRate, uint256 newRate)`: When fee rate is updated
- `OptionPoolUpdated(address indexed oldPool, address indexed newPool)`: When option pool is updated
- `EmergencyWithdraw(address indexed owner, uint256 amount)`: When emergency withdrawal occurs

## Security Considerations

### Inflation Attack Protection
The vault uses OpenZeppelin's ERC4626 implementation which includes protection against inflation attacks through virtual shares and assets.

### Reentrancy Protection
All state-changing functions are protected with the `nonReentrant` modifier.

### Access Control
Critical functions are restricted to the contract owner:
- Fee configuration updates
- Vault parameter updates
- Emergency functions
- Pause operations

### Input Validation
- Fee rates are capped at 10%
- Address parameters are validated for non-zero addresses
- Deposit amounts must meet minimum requirements
- Capacity limits are enforced

## Testing

The vault includes comprehensive tests covering:
- Basic ERC4626 functionality
- Fee collection and management
- Pause functionality
- Access control
- Emergency functions
- Edge cases and error conditions

Run tests with:
```bash
forge test --match-contract OptionPoolVaultTest -v
```

## Deployment

Use the provided deployment script:
```bash
forge script script/DeployOptionPoolVault.s.sol --rpc-url <RPC_URL> --broadcast
```

## Integration

### Option Pool Integration
The vault is designed to integrate with option pool contracts. Override the internal hook functions to add custom logic:

```solidity
function _afterDeposit(uint256 assets, uint256 shares, address receiver) internal virtual override {
    // Add custom logic for option pool integration
}

function _afterWithdraw(uint256 assets, uint256 shares, address receiver, address owner) internal virtual override {
    // Add custom logic for option pool integration
}
```

### Custom Extensions
Extend the vault by overriding the virtual functions:
- `_convertToShares()`: Custom conversion logic
- `_convertToAssets()`: Custom conversion logic
- `_deposit()`: Custom deposit logic
- `_withdraw()`: Custom withdrawal logic

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Ensure all tests pass
6. Submit a pull request

## Disclaimer

This software is provided "as is" without warranty of any kind. Use at your own risk. Always conduct thorough testing and security audits before deploying to production.
