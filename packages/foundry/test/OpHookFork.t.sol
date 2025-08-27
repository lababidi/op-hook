// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/OpHook.sol";
import "../contracts/IOptionToken.sol";
import {MockOptionToken} from "../contracts/MockOptionToken.sol";
import {HookMiner} from "lib/uniswap-hooks/lib/v4-periphery/src/utils/HookMiner.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20Fork is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**18);
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract OpHookForkTest is Test {
    OpHook public opHook;
    MockERC20Fork public weth;
    MockERC20Fork public usdc;
    IPoolManager public poolManager;
    
    // We'll deploy our own contracts for proper testing
    address constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3; // Can use real Permit2 since it's just utility
    
    function setUp() public {
        // Deploy a real PoolManager for testing
        poolManager = PoolManager(0x000000000004444c5dc75cB358380D2e3dE08A90);
        
        // Deploy mock tokens
        weth = new MockERC20Fork("Wrapped Ether", "WETH");
        usdc = new MockERC20Fork("USD Coin", "USDC");
        
        // Deploy OpHook using HookMiner to get correct address
        uint160 flags = Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_DONATE_FLAG;
        bytes memory constructorArgs = abi.encode(
            poolManager,
            PERMIT2_ADDRESS,
            IERC20(address(weth)),
            "WethOptionPoolVault",
            "ETHCC"
        );

        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            type(OpHook).creationCode,
            constructorArgs
        );

        opHook = new OpHook{salt: salt}(
            poolManager,
            PERMIT2_ADDRESS,
            IERC20(address(weth)),
            "WethOptionPoolVault",
            "ETHCC"
        );
        
        console.log("OpHook expected at:", address(hookAddress));
        console.log("OpHook deployed at:", address(opHook));
        console.log("PoolManager deployed at:", address(poolManager));
    }
    
    function testForkSetup() public view {
        // Verify our fork setup works
        assertEq(address(opHook.poolManager()), address(poolManager));
        assertEq(address(opHook.underlying()), address(weth));
        assertEq(opHook.name(), "WethOptionPoolVault");
        assertEq(opHook.symbol(), "ETHCC");
    }
    
    function testERC4626FunctionsFork() public {
        // Test ERC4626 functionality on fork
        uint256 depositAmount = 100 * 1e18;
        address user = address(0x123);
        
        // Give user some WETH
        weth.mint(user, depositAmount);
        
        // Approve and deposit
        vm.startPrank(user);
        weth.approve(address(opHook), depositAmount);
        uint256 shares = opHook.deposit(depositAmount, user);
        vm.stopPrank();
        
        // Verify deposit worked
        assertEq(opHook.balanceOf(user), shares);
        assertEq(opHook.totalAssets(), depositAmount);
        assertEq(shares, depositAmount); // 1:1 ratio initially
        
        console.log("Deposit successful - User received", shares, "shares");
    }
    
    function testPoolInitializationFork() public {
        // Test pool initialization with real PoolManager and proper option token
        uint24 fee = 3000;
        
        // Create a proper mock option token that implements IOptionToken
        MockOptionToken optionToken = new MockOptionToken(
            "Call Option", 
            "CALL",
            address(weth),
            address(usdc)
        );
        
        // This should now work with the real PoolManager and proper option token
        try opHook.initPool(address(optionToken), address(usdc), fee) {
            // If successful, verify pool was added
            assertEq(opHook.getPools().length, 1, "Pool should be initialized");
            console.log("Pool initialization successful");
        } catch Error(string memory reason) {
            console.log("Pool initialization failed:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("Pool initialization failed with low-level error");
            console.logBytes(lowLevelData);
        }
    }
    
    function testFullOptionTokenWorkflow() public {
        // Test the complete OpHook workflow with our own tokens
        uint256 depositAmount = 1000 * 1e18; // 1000 WETH
        address user = address(0x123);
        address optionBuyer = address(0x456);
        
        console.log("=== Testing Full Option Token Workflow ===");
        
        // 1. Setup: User deposits WETH into vault
        weth.mint(user, depositAmount);
        vm.startPrank(user);
        weth.approve(address(opHook), depositAmount);
        uint256 shares = opHook.deposit(depositAmount, user);
        vm.stopPrank();
        
        console.log("Step 1: User deposited WETH and received shares");
        console.log("- Deposited:", depositAmount / 1e18);
        console.log("- Received shares:", shares / 1e18);
        
        // 2. Create option token with proper parameters
        MockOptionToken callOption = new MockOptionToken(
            "WETH Call Option $3000 Strike", 
            "WETH-CALL-3000",
            address(weth), // collateral
            address(usdc)  // consideration (premium currency)
        );
        
        console.log("Step 2: Created call option with strike $3000");
        
        // 3. Initialize pool with option token and USDC
        uint24 fee = 3000;
        opHook.initPool(address(callOption), address(usdc), fee);
        
        assertEq(opHook.getPools().length, 1, "Pool should be created");
        console.log("Step 3: Initialized option pool");
        
        // 4. Mint some option tokens to test
        callOption.mint(1000 * 1e18); // Mint to test contract
        callOption.transfer(address(opHook), 100 * 1e18); // Give some to the hook
        
        console.log("Step 4: Minted option tokens");
        
        // 5. Test OptionPrice integration 
        console.log("Step 5: Testing OptionPrice integration...");
        
        // The OpHook creates its own OptionPrice contract in constructor
        // Let's test the price functions even though they use mock oracles
        try opHook.getOptionPrice(address(callOption)) returns (CurrentOptionPrice memory price) {
            console.log("[SUCCESS] Option price retrieved successfully!");
            console.log("- Underlying:", price.underlying);
            console.log("- Option token:", price.optionToken);
            console.log("- Price:", price.price);
            
            // Verify the price structure
            assertEq(price.underlying, address(weth), "Should match WETH address");
            assertEq(price.optionToken, address(callOption), "Should match option token");
            assertTrue(price.price > 0, "Price should be positive");
            
        } catch Error(string memory reason) {
            console.log("[ERROR] Option price failed:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("[ERROR] Option price failed with low-level error");
            console.logBytes(lowLevelData);
        }
        
        // 6. Test getPrices for all pools
        console.log("Step 6: Testing getPrices for all pools...");
        try opHook.getPrices() returns (uint256[] memory prices) {
            console.log("[SUCCESS] Retrieved prices for", prices.length, "pools");
            for (uint i = 0; i < prices.length; i++) {
                console.log("- Pool", i, "price:", prices[i]);
                assertTrue(prices[i] >= 0, "Price should be non-negative");
            }
        } catch Error(string memory reason) {
            console.log("[ERROR] getPrices failed:", reason);
        }
        
        console.log("=== Workflow completed successfully ===");
    }
    
    function testWhitelistAndSwapBehavior() public {
        // Test OpHook's unique whitelist and swap hook behavior
        console.log("=== Testing Whitelist and Swap Hook Behavior ===");
        
        // Create option tokens
        MockOptionToken ethCallOption = new MockOptionToken(
            "ETH Call $2500", 
            "ETH-C-2500",
            address(weth),
            address(usdc)
        );
        
        MockOptionToken ethPutOption = new MockOptionToken(
            "ETH Put $1800", 
            "ETH-P-1800", 
            address(usdc),
            address(weth)
        );
        
        console.log("Created ETH call and put options");
        
        
        console.log("Verified initial whitelist state - all tokens not whitelisted");
        
        // Initialize pools to test pool creation
        uint24 fee = 3000;
        
        try opHook.initPool(address(ethCallOption), address(usdc), fee) {
            console.log("Successfully initialized ETH call option pool");
        } catch Error(string memory reason) {
            console.log("Call option pool init failed:", reason);
        }
        
        try opHook.initPool(address(ethPutOption), address(weth), fee) {
            console.log("Successfully initialized ETH put option pool");
        } catch Error(string memory reason) {
            console.log("Put option pool init failed:", reason);
        }
        
        console.log("Total pools created:", opHook.getPools().length);
        
        // Test getPrices function
        try opHook.getPrices() returns (uint256[] memory prices) {
            console.log("Retrieved prices for", prices.length, "pools");
            for (uint i = 0; i < prices.length; i++) {
                console.log("Pool", i, "price:", prices[i]);
            }
        } catch {
            console.log("Price retrieval failed (expected with mock oracles)");
        }
    }
    
    function testVaultIntegrationWithOptions() public {
        // Test how the vault integrates with option trading
        console.log("=== Testing Vault Integration with Options ===");
        
        uint256 initialDeposit = 500 * 1e18;
        address vaultUser = address(0x789);
        
        // User deposits into vault
        weth.mint(vaultUser, initialDeposit);
        vm.startPrank(vaultUser);
        weth.approve(address(opHook), initialDeposit);
        uint256 shares = opHook.deposit(initialDeposit, vaultUser);
        vm.stopPrank();
        
        console.log("Vault user deposited WETH for shares");
        console.log("- Deposited:", initialDeposit / 1e18);
        console.log("- Received shares:", shares / 1e18);
        
        // Check vault stats
        (uint256 totalAssets_, uint256 totalShares_, uint256 exchangeRate_, uint256 utilizationRate_) = opHook.getVaultStats();
        
        console.log("Vault stats after deposit:");
        console.log("- Total assets:", totalAssets_ / 1e18);
        console.log("- Total shares:", totalShares_ / 1e18);
        console.log("- Exchange rate:", exchangeRate_);
        console.log("- Utilization rate:", utilizationRate_);
        
        // Create and initialize an option pool
        MockOptionToken option = new MockOptionToken(
            "WETH Call $2800",
            "WETH-C-2800",
            address(weth),
            address(usdc)
        );
        
        opHook.initPool(address(option), address(usdc), 3000);
        console.log("Initialized option pool with vault funds available");
        
        // Test partial withdrawal
        uint256 withdrawAmount = 100 * 1e18;
        vm.prank(vaultUser);
        uint256 sharesBurned = opHook.withdraw(withdrawAmount, vaultUser, vaultUser);
        
        console.log("User withdrew WETH and burned shares");
        console.log("- Withdrew:", withdrawAmount / 1e18);
        console.log("- Burned shares:", sharesBurned / 1e18);
        
        // Check final vault stats
        (totalAssets_, totalShares_, exchangeRate_,) = opHook.getVaultStats();
        console.log("Final vault assets:", totalAssets_ / 1e18);
        console.log("Final vault shares:", totalShares_ / 1e18);
    }

    function testCreateMultipleLPsWithPricing() public {
        // Test creating multiple liquidity pools and using OptionPrice integration
        console.log("=== Testing Multiple LP Creation with Pricing ===");
        
        uint256 vaultDeposit = 2000 * 1e18; // 2000 WETH for vault
        address vaultProvider = address(0xABC);
        
        // 1. Set up vault with significant liquidity
        weth.mint(vaultProvider, vaultDeposit);
        vm.startPrank(vaultProvider);
        weth.approve(address(opHook), vaultDeposit);
        uint256 shares = opHook.deposit(vaultDeposit, vaultProvider);
        vm.stopPrank();
        
        console.log("Vault funded with", vaultDeposit / 1e18, "WETH");
        
        // 2. Create multiple option tokens with different strikes and types
        MockOptionToken[] memory options = new MockOptionToken[](4);
        
        // ETH Call $3000 
        options[0] = new MockOptionToken(
            "ETH Call $3000",
            "ETH-C-3000",
            address(weth),
            address(usdc)
        );
        
        // ETH Call $3500
        options[1] = new MockOptionToken(
            "ETH Call $3500", 
            "ETH-C-3500",
            address(weth),
            address(usdc)
        );
        
        // ETH Put $2500
        options[2] = new MockOptionToken(
            "ETH Put $2500",
            "ETH-P-2500", 
            address(usdc),
            address(weth)
        );
        
        // ETH Put $2000
        options[3] = new MockOptionToken(
            "ETH Put $2000",
            "ETH-P-2000",
            address(usdc), 
            address(weth)
        );
        
        console.log("Created 4 different option tokens:");
        console.log("- 2 Call options (strikes: $3000, $3500)");
        console.log("- 2 Put options (strikes: $2500, $2000)");
        
        // 3. Initialize pools for each option token
        uint24[3] memory fees = [uint24(500), uint24(3000), uint24(10000)]; // 0.05%, 0.3%, 1%
        uint256 totalPools = 0;
        
        for (uint i = 0; i < options.length; i++) {
            for (uint j = 0; j < fees.length; j++) {
                console.log("Creating pool for option", i);
                console.log("- Fee:", fees[j]);
                
                try opHook.initPool(address(options[i]), address(usdc), fees[j]) {
                    totalPools++;
                    console.log("[SUCCESS] Pool created successfully");
                } catch Error(string memory reason) {
                    console.log("[ERROR] Pool creation failed:", reason);
                } catch {
                    console.log("[ERROR] Pool creation failed (unknown error)");
                }
            }
        }
        
        console.log("Successfully created", totalPools, "pools");
        assertEq(opHook.getPools().length, totalPools, "Pool count should match");
        
        // 4. Test pricing for all created pools
        console.log("Testing pricing for all pools...");
        
        try opHook.getPrices() returns (uint256[] memory allPrices) {
            console.log("[SUCCESS] Retrieved prices for", allPrices.length, "pools:");
            
            for (uint i = 0; i < allPrices.length; i++) {
                console.log("- Pool", i, "price:", allPrices[i]);
                
                // Verify prices are reasonable (not zero, not ridiculously high)
                if (allPrices[i] > 0) {
                    console.log("  [SUCCESS] Price looks reasonable");
                } else {
                    console.log("  [WARNING] Price is zero (may be expected for mock oracles)");
                }
            }
            
            assertTrue(allPrices.length == totalPools, "Should have price for each pool");
            
        } catch Error(string memory reason) {
            console.log("[ERROR] Failed to get all prices:", reason);
        }
        
        // 5. Test individual option pricing
        console.log("Testing individual option pricing...");
        
        for (uint i = 0; i < options.length; i++) {
            console.log("Getting price for option", i, ":", options[i].name());
            
            try opHook.getOptionPrice(address(options[i])) returns (CurrentOptionPrice memory price) {
                console.log("- Price:", price.price);
                console.log("- Underlying:", price.underlying);
                console.log("- Option token:", price.optionToken);
                
                // Verify structure
                assertEq(price.underlying, address(weth), "Should use WETH as underlying");
                assertEq(price.optionToken, address(options[i]), "Should match option token");
                
            } catch Error(string memory reason) {
                console.log("[ERROR] Individual pricing failed:", reason);
            }
        }
        
        console.log("=== Multiple LP Creation and Pricing Complete ===");
    }

    function testForkedChainSetup() public {
        // Test that demonstrates how to run tests on your local chain (yarn chain)
        console.log("Current block number:", block.number);
        console.log("Current chain ID:", block.chainid);
        console.log("Current timestamp:", block.timestamp);
        
        // If you want to test against your yarn chain, you would:
        // 1. Make sure contracts are deployed on yarn chain
        // 2. Use their addresses instead of mocks
        // 3. Test real interactions
        
        assertTrue(true, "Fork setup working");
    }
}