# 🎯 OpSwap - Decentralized Options Trading Platform

<h4 align="center">
  <a href="https://docs.scaffoldeth.io">Scaffold-ETH 2 Docs</a> |
  <a href="https://scaffoldeth.io">Scaffold-ETH 2 Website</a>
</h4>

🚀 A decentralized options trading platform built on Ethereum using Scaffold-ETH 2, Uniswap V4 hooks, and advanced DeFi protocols. OpSwap enables users to trade options with deep liquidity pools and sophisticated pricing models.

⚙️ Built using NextJS, RainbowKit, Foundry, Wagmi, Viem, TypeScript, and Uniswap V4.

## 🎯 Project Overview

OpSwap is a comprehensive options trading platform that combines:

- **🪝 Uniswap V4 Hooks**: Custom hooks for options trading integration
- **💰 Option Pool Vaults**: ERC4626 compliant vaults for managing option assets
- **📊 Black-Scholes Pricing**: Advanced options pricing using mathematical models
- **🔄 Liquidity Management**: Automated liquidity provision and management
- **🔐 Secure Trading**: Whitelisted tokens and permissioned trading

## 🏗️ Architecture

### Smart Contracts

- **`OpHook.sol`**: Uniswap V4 hook for options trading integration
- **`OptionPool.sol`**: Core options pool with cell-based liquidity management
- **`OptionPoolVault.sol`**: ERC4626 vault for option pool asset management
- **`OptionPrice.sol`**: Black-Scholes options pricing implementation
- **`IOptionToken.sol`**: Interface for option token interactions

### Frontend

- **NextJS App**: Modern React frontend with TypeScript
- **OpSwap Interface**: Dedicated options trading interface at `/opswapfront`
- **Debug Interface**: Contract interaction and testing tools
- **Block Explorer**: Local transaction monitoring

## 🚀 Quickstart

### Prerequisites

Before you begin, you need to install the following tools:

- [Node (>= v20.18.3)](https://nodejs.org/en/download/)
- Yarn ([v1](https://classic.yarnpkg.com/en/docs/install/) or [v2+](https://yarnpkg.com/getting-started/install))
- [Git](https://git-scm.com/downloads)

### Installation & Setup

1. **Install dependencies**:
```bash
yarn install
```

2. **Start local blockchain** (Terminal 1):
```bash
yarn chain
```

3. **Deploy contracts** (Terminal 2):
```bash
yarn deploy
```

4. **Start frontend** (Terminal 3):
```bash
yarn start
```

5. **Access the application**:
   - Main app: `http://localhost:3000`
   - OpSwap interface: `http://localhost:3000/opswapfront`
   - Debug contracts: `http://localhost:3000/debug`
   - Block explorer: `http://localhost:3000/blockexplorer`

### Testing

Run smart contract tests:
```bash
yarn foundry:test
```

## 🎯 Key Features

### Options Trading
- **Call & Put Options**: Support for both call and put option types
- **Black-Scholes Pricing**: Mathematical options pricing model
- **Strike Price Management**: Flexible strike price configuration
- **Expiration Handling**: Automated expiration and settlement

### Liquidity Management
- **Cell-Based Liquidity**: Efficient liquidity distribution across price ranges
- **Fee Collection**: Automated fee collection and distribution
- **Position Management**: Advanced position tracking and management
- **Vault Integration**: ERC4626 compliant vault for asset management

### Security & Access Control
- **Whitelisted Tokens**: Permissioned trading for approved tokens
- **Access Control**: Role-based permissions for admin functions
- **Emergency Pause**: Circuit breakers for emergency situations
- **Reentrancy Protection**: Secure contract interactions

## 🛠️ Development

### Smart Contract Development

- **Contracts**: `packages/foundry/contracts/`
- **Tests**: `packages/foundry/test/`
- **Deployment Scripts**: `packages/foundry/script/`

### Frontend Development

- **Main App**: `packages/nextjs/app/page.tsx`
- **OpSwap Interface**: `packages/nextjs/app/opswapfront/page.tsx`
- **Components**: `packages/nextjs/components/`
- **Hooks**: `packages/nextjs/hooks/scaffold-eth/`

### Configuration

- **Scaffold Config**: `packages/nextjs/scaffold.config.ts`
- **Foundry Config**: `packages/foundry/foundry.toml`
- **Deployed Contracts**: `packages/nextjs/contracts/deployedContracts.ts`

## 🔧 Contract Interactions

### Reading Data
```typescript
const { data: optionPrice } = useScaffoldReadContract({
  contractName: "OptionPrice",
  functionName: "blackScholesPrice",
  args: [underlying, strike, timeToExpiration, volatility, riskFreeRate, isCall],
});
```

### Writing Data
```typescript
const { writeContractAsync: writeOpHookAsync } = useScaffoldWriteContract({
  contractName: "OpHook"
});

await writeOpHookAsync({
  functionName: "addLiquidity",
  args: [permit, key, liquidityParams, hookData],
});
```

## 📚 Documentation

- [Scaffold-ETH 2 Documentation](https://docs.scaffoldeth.io)
- [Uniswap V4 Documentation](https://docs.uniswap.org/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)

## 🤝 Contributing

We welcome contributions to OpSwap! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENCE) file for details.

## ⚠️ Disclaimer

This software is for educational and development purposes. Use at your own risk. The contracts have not been audited and should not be used in production without proper security review.