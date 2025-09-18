// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @title Constants
/// @notice Central place for all project-wide constants
library ConstantsUnichain {
    // Example addresses (update as needed for your environment)
    address public constant WETH = 0x4200000000000000000000000000000000000006;
    address public constant USDC = 0x078D782b760474a361dDA0AF3839290b0EF57AD6;
    address public constant UNI = 0x8f187aA05619a017077f5308904739877ce9eA21;

    address public constant POOLMANAGER = 0x1F98400000000000000000000000000000000004;
    address public constant POSITIONDESCRIPTOR = 0x9fb28449a191CD8C03a1B7abfb0F5996ECf7f722;
    address public constant POSITIONMANAGER = 0x4529A01c7A0410167c5740C487A8DE60232617bf;
    address public constant QUOTER = 0x333E3C607B141b18fF6de9f258db6e77fE7491E0;
    address public constant STATEVIEW = 0x86e8631A016F9068C3f085fAF484Ee3F5fDee8f2;
    address public constant UNIVERSALROUTER = 0xEf740bf23aCaE26f6492B10de645D6B98dC8Eaf3;
    address public constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address public constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    address public constant WETH_UNI_POOL = 0x65081CB48d74A32e9CCfED75164b8c09972DBcF1;

    // Decimals
    uint8 public constant WETH_DECIMALS = 18;
    uint8 public constant USDC_DECIMALS = 6;

    // Time-related constants
    uint256 public constant SECONDS_PER_YEAR = 31536000;

    // Option pricing defaults
    uint256 public constant DEFAULT_VOLATILITY = 2e17; // 20% annualized, 1e18 scale
    uint256 public constant DEFAULT_RISK_FREE_RATE = 5e16; // 5% annualized, 1e18 scale

    // Uniswap V3 pool fee tiers
    uint24 public constant FEE_TIER_LOW = 500;    // 0.05%
    uint24 public constant FEE_TIER_MEDIUM = 3000; // 0.3%
    uint24 public constant FEE_TIER_HIGH = 10000;  // 1%


}
