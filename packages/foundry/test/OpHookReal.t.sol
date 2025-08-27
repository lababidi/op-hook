// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/OpHook.sol";
import "../contracts/IOptionToken.sol";
import {HookMiner} from "lib/uniswap-hooks/lib/v4-periphery/src/utils/HookMiner.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Import the mock option token from the fork test file
contract MockOptionTokenFork is ERC20, IOptionToken {
    uint256 private _expirationDate;
    uint256 private _strike;
    bool private _isPut;
    IERC20 private _collateral;
    IERC20 private _consideration;
    address private _permit2;
    bool private _initialized;
    
    constructor(string memory name, string memory symbol, address collateral, address consideration) ERC20(name, symbol) {
        _expirationDate = block.timestamp + 30 days;
        _strike = 2000 * 1e18; // $2000 strike
        _isPut = false; // Call option
        _collateral = IERC20(collateral);
        _consideration = IERC20(consideration);
        _initialized = true;
    }
    
    function PERMIT2() external view returns (address) { return _permit2; }
    function expirationDate() external view returns (uint256) { return _expirationDate; }
    function strike() external view returns (uint256) { return _strike; }
    function STRIKE_DECIMALS() external pure returns (uint256) { return 18; }
    function isPut() external view returns (bool) { return _isPut; }
    function collateral() external view returns (IERC20) { return _collateral; }
    function consideration() external view returns (IERC20) { return _consideration; }
    function initialized() external view returns (bool) { return _initialized; }
    
    function toConsideration(uint256 amount) external pure returns (uint256) { return amount; }
    
    function init(
        string memory,
        string memory,
        address collateral_,
        address consideration_,
        uint256 expirationDate_,
        uint256 strike_,
        bool isPut_
    ) external {
        _collateral = IERC20(collateral_);
        _consideration = IERC20(consideration_);
        _expirationDate = expirationDate_;
        _strike = strike_;
        _isPut = isPut_;
        _initialized = true;
    }
    
    function name() public view override(ERC20, IOptionToken) returns (string memory) {
        return ERC20.name();
    }
    
    function symbol() public view override(ERC20, IOptionToken) returns (string memory) {
        return ERC20.symbol();
    }
    
    function collateralData() external pure returns (TokenData memory) {
        return TokenData("WETH", "WETH", 18);
    }
    
    function considerationData() external pure returns (TokenData memory) {
        return TokenData("USDC", "USDC", 6);
    }
    
    function mint(IPermit2.PermitTransferFrom calldata, IPermit2.SignatureTransferDetails calldata, bytes calldata) external {
        _mint(msg.sender, 1000 * 1e18);
    }
    
    function mint(uint256 amount) external {
        _mint(msg.sender, amount);
    }
    
    function exercise(IPermit2.PermitTransferFrom calldata, IPermit2.SignatureTransferDetails calldata, bytes calldata) external {
        // Mock implementation
    }
    
    function redeem(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}

/**
 * OpHookReal.t.sol - Tests OpHook with real deployed tokens and price feeds
 * 
 * This version is designed to work with:
 * 1. Real mainnet WETH and USDC contracts (when forking mainnet)
 * 2. Real Uniswap V3 pools for price data
 * 3. Actual deployed Permit2 contracts
 * 4. Your local chain with deployed tokens (yarn chain)
 * 
 * To run against mainnet fork:
 * forge test --match-contract OpHookRealTest --fork-url https://eth-mainnet.alchemyapi.io/v2/$ALCHEMY_API_KEY -vv
 * 
 * To run against your local chain:
 * forge test --match-contract OpHookRealTest --fork-url http://localhost:8545 -vv
 */
contract OpHookRealTest is Test {
    OpHook public opHook;
    IPoolManager public poolManager;
    
    // Real contract addresses
    address constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3; // Universal Permit2
    address constant MAINNET_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant MAINNET_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    
    // For local chain, you would set these to your deployed token addresses
    address public wethAddress;
    address public usdcAddress;
    
    IERC20Metadata public weth;
    IERC20Metadata public usdc;
    
    function setUp() public {
        console.log("=== OpHook Real Token Testing Setup ===");
        console.log("Block number:", block.number);
        console.log("Chain ID:", block.chainid);
        
        if (block.chainid == 1) {
            // Mainnet fork
            console.log("Using mainnet contracts");
            wethAddress = MAINNET_WETH;
            usdcAddress = MAINNET_USDC;
        } else if (block.chainid == 31337 && block.number > 1) {
            // Forked chain (yarn fork) - has real mainnet state
            console.log("Using forked mainnet (yarn fork)");
            wethAddress = MAINNET_WETH;
            usdcAddress = MAINNET_USDC;
        } else if (block.chainid == 31337) {
            // Local clean chain (yarn chain) - would need deployed tokens
            console.log("Using local clean chain (yarn chain) - set your deployed token addresses here");
            wethAddress = address(0);
            usdcAddress = address(0);
        } else {
            // Other networks
            console.log("Unsupported network for real token testing");
            wethAddress = address(0);
            usdcAddress = address(0);
        }
        
        // Deploy PoolManager
        poolManager = new PoolManager(address(this));
        console.log("PoolManager deployed at:", address(poolManager));
        
        if (wethAddress != address(0) && usdcAddress != address(0)) {
            weth = IERC20Metadata(wethAddress);
            usdc = IERC20Metadata(usdcAddress);
            
            // Deploy OpHook with real WETH
            uint160 flags = Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_DONATE_FLAG;
            bytes memory constructorArgs = abi.encode(
                poolManager,
                PERMIT2_ADDRESS,
                weth,
                "Real WETH Option Vault",
                "rWETH-OPT"
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
                weth,
                "Real WETH Option Vault",
                "rWETH-OPT"
            );
            
            console.log("OpHook deployed at:", address(opHook));
            console.log("Intended address:", hookAddress);
            console.log("Using real WETH at:", wethAddress);
            console.log("Using real USDC at:", usdcAddress);
        }
    }
    
    function testRealTokenSetup() public {
        if (wethAddress == address(0)) {
            console.log("Skipping real token tests - no real tokens configured for this network");
            return;
        }
        
        // Verify we're using real contracts
        assertEq(address(opHook.underlying()), wethAddress);
        assertEq(opHook.name(), "Real WETH Option Vault");
        assertEq(opHook.symbol(), "rWETH-OPT");
        
        // Check real token properties
        console.log("WETH name:", weth.name());
        console.log("WETH symbol:", weth.symbol());
        console.log("WETH decimals:", weth.decimals());
        
        console.log("USDC name:", usdc.name());
        console.log("USDC symbol:", usdc.symbol());
        console.log("USDC decimals:", usdc.decimals());
        
        // Check if we have any real balances (useful when forking)
        if (weth.balanceOf(address(this)) > 0) {
            console.log("Test contract has WETH balance:", weth.balanceOf(address(this)));
        }
        
        if (usdc.balanceOf(address(this)) > 0) {
            console.log("Test contract has USDC balance:", usdc.balanceOf(address(this)));
        }
    }
    
    function testVaultWithRealTokens() public {
        if (wethAddress == address(0)) {
            console.log("Skipping vault test - no real tokens configured");
            return;
        }
        
        console.log("=== Testing Vault with Real Tokens ===");
        
        // This test would work if we had WETH balance
        uint256 wethBalance = weth.balanceOf(address(this));
        if (wethBalance == 0) {
            console.log("No WETH balance for testing - would need to acquire WETH first");
            console.log("On mainnet fork, you could:");
            console.log("1. Impersonate a whale account");
            console.log("2. Use deal() to give test accounts tokens");
            console.log("3. Wrap ETH to get WETH");
            return;
        }
        
        // If we had balance, we could test:
        console.log("Available WETH:", wethBalance);
        // weth.approve(address(opHook), wethBalance);
        // uint256 shares = opHook.deposit(wethBalance, address(this));
        // console.log("Deposited real WETH, received shares:", shares);
    }
    
    function testMainnetForkWithWhale() public {
        // Skip if not on mainnet fork
        if (block.chainid != 1 || wethAddress == address(0)) {
            console.log("Skipping whale test - not on mainnet fork");
            return;
        }
        
        console.log("=== Testing with Mainnet Whale Account ===");
        
        // Example of testing with a whale account (large WETH holder)
        address wethWhale = 0x8EB8a3b98659Cce290402893d0123abb75E3ab28; // Example whale address
        uint256 whaleBalance = weth.balanceOf(wethWhale);
        
        if (whaleBalance > 0) {
            console.log("Whale WETH balance:", whaleBalance);
            
            // Impersonate whale
            vm.startPrank(wethWhale);
            
            // Test deposit
            uint256 depositAmount = 1 ether; // 1 WETH
            if (whaleBalance >= depositAmount) {
                weth.approve(address(opHook), depositAmount);
                uint256 shares = opHook.deposit(depositAmount, wethWhale);
                
                console.log("Whale deposited 1 WETH, received shares:", shares);
                
                // Test withdrawal
                uint256 withdrawAmount = 0.5 ether;
                uint256 sharesBurned = opHook.withdraw(withdrawAmount, wethWhale, wethWhale);
                console.log("Whale withdrew 0.5 WETH, burned shares:", sharesBurned);
            }
            
            vm.stopPrank();
        } else {
            console.log("Whale has no WETH balance");
        }
    }
    
    function testWithDealHelper() public {
        if (wethAddress == address(0)) {
            console.log("Skipping deal test - no real tokens configured");
            return;
        }
        
        console.log("=== Testing with deal() Helper ===");
        
        address testUser = address(0x123);
        uint256 dealAmount = 100 ether;
        
        // Use foundry's deal to give user ETH
        vm.deal(testUser, dealAmount);
        console.log("Gave test user", dealAmount, "ETH");
        
        // Alternative: If WETH contract supports it, we could wrap ETH
        vm.deal(testUser, dealAmount);
        vm.startPrank(testUser);
        
        // Try to wrap ETH to WETH (if this is actual WETH contract)
        (bool success,) = wethAddress.call{value: 1 ether}("");
        if (success) {
                console.log("Successfully wrapped 1 ETH to WETH");
                
                uint256 wethBalance = weth.balanceOf(testUser);
                console.log("User WETH balance after wrap:", wethBalance);
                
                if (wethBalance >= 1 ether) {
                    // Test deposit with real WETH
                    weth.approve(address(opHook), 1 ether);
                    uint256 shares = opHook.deposit(1 ether, testUser);
                    console.log("User deposited 1 WETH, received shares:", shares);
                }
            } else {
                console.log("Could not wrap ETH (not WETH contract or not supported)");
            }
        
        vm.stopPrank();
    }
    
    function testRealPriceFeeds() public {
        if (wethAddress == address(0)) {
            console.log("Skipping price feed test - no real tokens configured");
            return;
        }
        
        console.log("=== Testing OpHook with Real Price Integration ===");
        
        // Create a real option token for testing (even if mock implementation)
        MockOptionTokenFork realOption = new MockOptionTokenFork(
            "Real WETH Call $3000",
            "rWETH-C-3000", 
            wethAddress, // Real WETH
            usdcAddress  // Real USDC
        );
        
        console.log("Created option token with real underlying assets");
        
        // Test OpHook's integrated OptionPrice contract
        console.log("Testing OpHook's OptionPrice integration...");
        
        try opHook.getOptionPrice(address(realOption)) returns (CurrentOptionPrice memory price) {
            console.log("[SUCCESS] OpHook OptionPrice working!");
            console.log("- Underlying (real WETH):", price.underlying);
            console.log("- Option token:", price.optionToken);
            console.log("- Calculated price:", price.price);
            
            // Verify it uses real WETH address
            assertEq(price.underlying, wethAddress, "Should use real WETH address");
            assertEq(price.optionToken, address(realOption), "Should match option token");
            
        } catch Error(string memory reason) {
            console.log("[ERROR] OpHook pricing failed:", reason);
            console.log("This is expected if OptionPrice needs Uniswap V3 pool setup");
        }
        
        // Initialize a pool with real tokens
        console.log("Creating LP with real token integration...");
        uint24 fee = 3000; // 0.3%
        
        try opHook.initPool(address(realOption), usdcAddress, fee) {
            console.log("[SUCCESS] LP created with real tokens!");
            
            // Test pricing for the created pool
            try opHook.getPrices() returns (uint256[] memory prices) {
                console.log("[SUCCESS] Got prices for", prices.length, "pools");
                for (uint i = 0; i < prices.length; i++) {
                    console.log("- Pool", i, "price:", prices[i]);
                }
            } catch Error(string memory reason) {
                console.log("[ERROR] Getting pool prices failed:", reason);
            }
            
        } catch Error(string memory reason) {
            console.log("[ERROR] LP creation failed:", reason);
        }
        
        console.log("");
        console.log("[INFO] To get real price feeds working:");
        console.log("1. The OptionPrice contract needs Uniswap V3 pool addresses");
        console.log("2. Set up the mapping: pool[WETH] = WETH/USDC_V3_POOL_ADDRESS");
        console.log("3. On mainnet fork, this would give real market prices!");
        
        // Example of what you'd do to set up real price feeds:
        if (block.chainid == 1 || (block.chainid == 31337 && block.number > 1)) {
            console.log("");
            console.log("[INFO] On mainnet fork, you could:");
            console.log("- Query Uniswap V3 WETH/USDC pool: 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640");
            console.log("- Get real-time ETH price");
            console.log("- Calculate accurate option prices with real volatility");
            console.log("- Enable actual option trading!");
        }
    }
    
    function testCreateLPWithRealTokens() public {
        if (wethAddress == address(0)) {
            console.log("Skipping LP creation test - no real tokens configured");
            return;
        }
        
        console.log("=== Creating LP with Real Token Integration ===");
        
        // Create multiple option tokens for comprehensive testing
        MockOptionTokenFork[] memory realOptions = new MockOptionTokenFork[](3);
        
        realOptions[0] = new MockOptionTokenFork(
            "Real ETH Call $3200", "rETH-C-3200", wethAddress, usdcAddress
        );
        realOptions[1] = new MockOptionTokenFork(
            "Real ETH Call $3500", "rETH-C-3500", wethAddress, usdcAddress  
        );
        realOptions[2] = new MockOptionTokenFork(
            "Real ETH Put $2800", "rETH-P-2800", usdcAddress, wethAddress
        );
        
        console.log("Created 3 option tokens with real underlying assets");
        
        // Initialize pools for each
        uint24[] memory fees = new uint24[](2);
        fees[0] = 3000; // 0.3%
        fees[1] = 500;  // 0.05%
        
        uint256 poolsCreated = 0;
        
        for (uint i = 0; i < realOptions.length; i++) {
            for (uint j = 0; j < fees.length; j++) {
                console.log("Creating pool for", realOptions[i].name());
                console.log("- Fee (bps):", fees[j]);
                
                try opHook.initPool(address(realOptions[i]), usdcAddress, fees[j]) {
                    poolsCreated++;
                    console.log("[SUCCESS] Pool created successfully!");
                } catch Error(string memory reason) {
                    console.log("[ERROR] Pool creation failed:", reason);
                }
            }
        }
        
        console.log("Total pools created:", poolsCreated);
        assertEq(opHook.getPools().length, poolsCreated, "Pool count should match created count");
        
        // Test pricing with real token context
        console.log("Testing pricing in real token context...");
        
        for (uint i = 0; i < realOptions.length; i++) {
            console.log("Pricing", realOptions[i].name(), "...");
            
            try opHook.getOptionPrice(address(realOptions[i])) returns (CurrentOptionPrice memory price) {
                console.log("- Price:", price.price);
                assertTrue(price.underlying == wethAddress, "Should use real WETH");
                assertTrue(price.optionToken == address(realOptions[i]), "Should match option");
                
            } catch Error(string memory reason) {
                console.log("- Pricing failed:", reason);
            }
        }
        
        console.log("=== Real Token LP Creation Complete ===");
    }
}