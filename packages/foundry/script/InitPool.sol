// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script, console } from "forge-std/Script.sol";
import { ScaffoldETHDeploy } from "./DeployHelpers.s.sol";
import { PoolKey } from "@uniswap/v4-core/src/types/PoolKey.sol";
import { PoolId } from "@uniswap/v4-core/src/types/PoolId.sol";
import { Currency } from "@uniswap/v4-core/src/types/Currency.sol";
import { IHooks } from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import { TickMath } from "@uniswap/v4-core/src/libraries/TickMath.sol";
import { CurrencyLibrary } from "@uniswap/v4-core/src/types/Currency.sol";
import { StateLibrary } from "@uniswap/v4-core/src/libraries/StateLibrary.sol";

/**
 * @notice Script to initialize a new Uniswap V4 pool on Sepolia testnet
 * @dev This script creates a pool with your custom hook contract
 * 
 * Usage:
 * 1. Set your hook contract address in the HOOK_ADDRESS constant
 * 2. Set your token addresses in TOKEN0_ADDRESS and TOKEN1_ADDRESS
 * 3. Adjust fee and tickSpacing as needed
 * 4. Run: forge script script/InitPool.sol --rpc-url sepolia --broadcast --verify
 */


contract InitPoolScript is ScaffoldETHDeploy {
    // ============ CONFIGURATION ============
    
    // TODO: Replace with your deployed hook contract address
    address constant HOOK_ADDRESS = address(0xCA2A914BA5fdFaaD2989CC21A93F172701078080);
    
    // option tokens
    // '0xadeFC3Ca8AB9974E4F3e3B5e09e94305988323Dd', '0xC40683e575391B60D7E20Ef284432b84c7276c02']
    // TODO: Replace with your token addresses (must be sorted numerically)
    address constant TOKEN0_ADDRESS = address(0x083dC0B99F583B5F6eD9c86612B3CcB8e8845b4A);
    address constant TOKEN1_ADDRESS = address(0x6550c8d40f06c8A5B003A0622538980Fc4AF7492);
    // Pool configuration
    uint24 constant FEE = 0; // 0.3% fee tier
    int24 constant TICK_SPACING = 60; // Standard for 0.3% fee tier
    
    // Initial price: 1:1 ratio (you can adjust this)
    // For a 1:1 price ratio, we use tick 0 which corresponds to sqrtPriceX96 = 2^96
    uint160 constant INITIAL_SQRT_PRICE_X96 = 79228162514264337593543950336; // 2^96 (1:1 price)
    
    // Sepolia PoolManager address (you may need to verify this)
    address constant POOL_MANAGER_ADDRESS = address(0xE03A1074c86CFeDd5C142C4F04F1a1536e203543);
    
    
    // ============ MAIN FUNCTION ============
    
    function run() external ScaffoldEthDeployerRunner {
        console.log("Starting pool initialization on Sepolia...");
        console.log("Deployer:", deployer);
        console.log("Hook address:", HOOK_ADDRESS);
        console.log("Token0:", TOKEN0_ADDRESS);
        console.log("Token1:", TOKEN1_ADDRESS);
        console.log("Fee:", FEE);
        console.log("Tick spacing:", TICK_SPACING);
        console.log("Initial sqrtPriceX96:", INITIAL_SQRT_PRICE_X96);
        
        // Validate addresses
        require(HOOK_ADDRESS != address(0), "Hook address cannot be zero");
        require(TOKEN0_ADDRESS != address(0), "Token0 address cannot be zero");
        require(TOKEN1_ADDRESS != address(0), "Token1 address cannot be zero");
        require(TOKEN0_ADDRESS != TOKEN1_ADDRESS, "Token0 and Token1 must be different");
        
        // Ensure tokens are sorted numerically (currency0 < currency1)
        require(TOKEN0_ADDRESS < TOKEN1_ADDRESS, "Tokens must be sorted numerically");
        
        // Create PoolKey
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(TOKEN0_ADDRESS),
            currency1: Currency.wrap(TOKEN1_ADDRESS),
            fee: FEE,
            tickSpacing: TICK_SPACING,
            // hooks: IHooks(HOOK_ADDRESS)
            hooks: IHooks(address(0))
        });
        
        // Get pool ID for logging
        PoolId poolId = poolKey.toId();
        console.log("Pool ID:", vm.toString(PoolId.unwrap(poolId)));
        
        // Initialize the pool
        IPoolManager poolManager = IPoolManager(POOL_MANAGER_ADDRESS);
        
        console.log("Initializing pool...");
        int24 tick = poolManager.initialize(poolKey, INITIAL_SQRT_PRICE_X96);
        
        console.log("Pool initialized successfully!");
        console.log("Initial tick:", tick);
        
        // Verify the pool was initialized correctly
        (uint160 sqrtPriceX96, int24 currentTick, uint24 protocolFee, uint24 lpFee) = StateLibrary.getSlot0(poolManager, poolId);
        console.log("Verification:");
        console.log("  sqrtPriceX96:", sqrtPriceX96);
        console.log("  currentTick:", currentTick);
        console.log("  protocolFee:", protocolFee);
        console.log("  lpFee:", lpFee);
        
        // Add to deployments for tracking
        deployments.push(Deployment("Pool", address(uint160(uint256(PoolId.unwrap(poolId))))));
        
        console.log("Pool initialization completed successfully!");
    }
    
}
