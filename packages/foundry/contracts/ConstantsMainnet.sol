// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

/// @title Constants
/// @notice Central place for all project-wide constants
library ConstantsMainnet {
    // Example addresses (update as needed for your environment)
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address public constant POOLMANAGER = 0x000000000004444c5dc75cB358380D2e3dE08A90;
    address public constant POSITIONDESCRIPTOR = 0xd1428Ba554F4C8450b763a0B2040A4935c63f06C;
    address public constant POSITIONMANAGER = 0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e;
    address public constant QUOTER = 0x52F0E24D1c21C8A0cB1e5a5dD6198556BD9E1203;
    address public constant STATEVIEW = 0x7fFE42C4a5DEeA5b0feC41C94C136Cf115597227;
    address public constant UNIVERSALROUTER = 0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af;
    address public constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    
    address public constant WETH_UNI_POOL = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;

    address public constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;


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
