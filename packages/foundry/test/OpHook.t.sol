// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/OpHook.sol";
import "../contracts/IOptionToken.sol";
import "../contracts/MockOptionToken.sol";
import {HookMiner} from "lib/uniswap-hooks/lib/v4-periphery/src/utils/HookMiner.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IWETH9} from "lib/v4-periphery/src/interfaces/external/IWETH9.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**18); // Mint 1M tokens to deployer
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}


contract OpHookTest is Test {
    // Real Mainnet addresses for testing
    address constant MOCK_POOL_MANAGER = address(0x000000000004444c5dc75cB358380D2e3dE08A90);
    address constant MOCK_PERMIT2 = address(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    address constant MAINNET_WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant MAINNET_USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    OpHook public opHook;
    IERC20 public usdc;
    IWETH9 public weth;
    address weth_ = MAINNET_WETH;
    address usdc_ = MAINNET_USDC;
    MockOptionToken public mockOptionToken;
    
    
    function setUp() public {
        // Deploy mock tokens
        weth = IWETH9(MAINNET_WETH);
        usdc = IERC20(MAINNET_USDC);
        mockOptionToken = new MockOptionToken("MockOption", "MOPT", weth_, usdc_);
        // Deploy OpHook using HookMiner to get correct address
        uint160 flags = Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_DONATE_FLAG;
        bytes memory constructorArgs = abi.encode(
            IPoolManager(MOCK_POOL_MANAGER),
            MOCK_PERMIT2,
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
            IPoolManager(MOCK_POOL_MANAGER),
            MOCK_PERMIT2,
            weth,
            "WethOptionPoolVault",
            "ETHCC"
        );
        console.log("Address", hookAddress);
        console.log("Address", address(opHook));
    }



    function testInitPool() public {
        // Test initializing a pool with option token and cash
        uint24 fee = 0; // 0.3% fee
        
        // Check initial state - no pools
        assertEq(opHook.getPools().length, 0);
        
        // Initialize a pool
        opHook.initPool(address(mockOptionToken), address(usdc), fee);
        
        // Verify pool was added
        assertEq(opHook.getPools().length, 1, "Pool should be added to the pools array");
        
        // Test that we can initialize multiple pools
        MockOptionToken mockOptionToken2 = new MockOptionToken("MockOption2", "MOPT2", MAINNET_WETH, MAINNET_USDC);
        opHook.initPool(address(mockOptionToken2), address(usdc), fee);
        assertEq(opHook.getPools().length, 2, "Second pool should be added");
    }

    function testERC4626Deposit() public {
        // Test ERC4626 deposit functionality
        uint256 depositAmount = 100 * 1e18; // 100 WETH
        address user = address(0x123);
        
        // Give user some WETH  
        deal(address(weth), user, depositAmount);
        
        // Approve the hook to spend WETH
        vm.prank(user);
        weth.approve(address(opHook), depositAmount);
        
        // Get initial balances
        uint256 initialWethBalance = weth.balanceOf(user);
        uint256 initialShares = opHook.balanceOf(user);
        
        // Deposit WETH to the vault
        vm.prank(user);
        uint256 sharesReceived = opHook.deposit(depositAmount, user);
        
        // Verify deposit
        assertEq(weth.balanceOf(user), initialWethBalance - depositAmount, "User WETH should be debited");
        assertEq(opHook.balanceOf(user), initialShares + sharesReceived, "User should receive shares");
        assertEq(opHook.totalAssets(), depositAmount, "Vault should hold deposited assets");
        assertEq(opHook.totalSupply(), sharesReceived, "Total shares should equal issued shares");
        
        // Verify 1:1 ratio initially (no yield yet)
        assertEq(sharesReceived, depositAmount, "Should receive 1:1 shares initially");
    }

    function testERC4626Withdraw() public {
        // First deposit some assets
        uint256 depositAmount = 100 * 1e18;
        address user = address(0x123);
        
        // Setup: deposit assets
        deal(address(weth), user, depositAmount);
        vm.prank(user);
        weth.approve(address(opHook), depositAmount);
        vm.prank(user);
        uint256 shares = opHook.deposit(depositAmount, user);
        
        // Now test withdrawal
        uint256 withdrawAmount = 50 * 1e18; // Withdraw 50 WETH
        uint256 initialWethBalance = weth.balanceOf(user);
        
        vm.prank(user);
        uint256 sharesBurned = opHook.withdraw(withdrawAmount, user, user);
        
        // Verify withdrawal
        assertEq(weth.balanceOf(user), initialWethBalance + withdrawAmount, "User should receive WETH");
        assertEq(opHook.balanceOf(user), shares - sharesBurned, "User shares should be reduced");
        assertEq(opHook.totalAssets(), depositAmount - withdrawAmount, "Vault assets should be reduced");
    }

    function testERC4626MintRedeem() public {
        // Test ERC4626 mint and redeem functionality
        uint256 sharesToMint = 100 * 1e18; // 100 shares
        address user = address(0x456);
        
        // Give user enough WETH (more than needed for minting)
        deal(address(weth), user, 200 * 1e18);
        
        // Approve the hook to spend WETH
        vm.prank(user);
        weth.approve(address(opHook), 200 * 1e18);
        
        // Test mint
        vm.prank(user);
        uint256 assetsUsed = opHook.mint(sharesToMint, user);
        
        // Verify mint (should be 1:1 initially)
        assertEq(opHook.balanceOf(user), sharesToMint, "User should receive requested shares");
        assertEq(assetsUsed, sharesToMint, "Should use 1:1 assets initially");
        assertEq(opHook.totalSupply(), sharesToMint, "Total supply should equal minted shares");
        
        // Test redeem
        uint256 sharesToRedeem = 50 * 1e18; // Redeem 50 shares
        uint256 initialWethBalance = weth.balanceOf(user);
        
        vm.prank(user);
        uint256 assetsReceived = opHook.redeem(sharesToRedeem, user, user);
        
        // Verify redeem
        assertEq(opHook.balanceOf(user), sharesToMint - sharesToRedeem, "User shares should be reduced");
        assertEq(weth.balanceOf(user), initialWethBalance + assetsReceived, "User should receive WETH");
        assertEq(assetsReceived, sharesToRedeem, "Should receive 1:1 assets initially");
    }
    
    function testGetVaultStats() public {
        // Test getVaultStats function
        (uint256 totalAssets_, uint256 totalShares_, uint256 exchangeRate_, uint256 utilizationRate_) = opHook.getVaultStats();
        
        // Initially should be empty
        assertEq(totalAssets_, 0, "No assets initially");
        assertEq(totalShares_, 0, "No shares initially");
        assertEq(exchangeRate_, 1e18, "Exchange rate should be 1e18 initially");
        assertEq(utilizationRate_, 0, "Utilization rate should be 0");
        
        // After deposit, stats should update
        uint256 depositAmount = 100 * 1e18;
        address user = address(0x789);
        deal(address(weth), user, depositAmount);
        vm.prank(user);
        weth.approve(address(opHook), depositAmount);
        vm.prank(user);
        opHook.deposit(depositAmount, user);
        
        (totalAssets_, totalShares_, exchangeRate_,) = opHook.getVaultStats();
        assertEq(totalAssets_, depositAmount, "Total assets should equal deposit");
        assertEq(totalShares_, depositAmount, "Total shares should equal deposit");
        assertEq(exchangeRate_, 1e18, "Exchange rate should remain 1e18");
    }

    
    function testGetOptionPrice() public view {
        // Test getOptionPrice function with mock option token
        // Note: This will likely fail because OptionPrice needs proper setup,
        // but let's test the interface
        CurrentOptionPrice memory price = opHook.getOptionPrice(address(mockOptionToken));
        // If it doesn't revert, verify the structure
        assertEq(price.underlying, address(weth), "Underlying should match");
        assertEq(price.optionToken, address(mockOptionToken), "Option token should match");
        console.log("price", price.price);
        // Price could be any value, just check it's returned
        assertTrue(price.price >= 0, "Price should be non-negative");

    }

    function testUserAccountWithEthWethAndSwap() public {
        // Set up user account
        address user = address(0x123456789);
        uint256 initialEthAmount = 10 ether;
        
        // Deal ETH to user account
        vm.deal(user, initialEthAmount);
        assertEq(user.balance, initialEthAmount, "User should have initial ETH");
        
        // Wrap ETH to WETH
        uint256 wrapAmount = 5 ether;
        vm.prank(user);
        weth.deposit{value: wrapAmount}();
        
        // Verify WETH balance
        assertEq(weth.balanceOf(user), wrapAmount, "User should have WETH");
        assertEq(user.balance, initialEthAmount - wrapAmount, "User ETH should be reduced");
        
        // For swapping to USDC, we'll use a simple approach with deal
        // In a real test, you'd integrate with Uniswap V3 or another DEX
        // For now, we'll simulate receiving USDC after "swapping"
        uint256 swapAmount = 2 ether; // 2 WETH to swap
        uint256 usdcReceived = 4000 * 1e6; // Assume ~$2000 per ETH, USDC has 6 decimals
        
        // Approve WETH spending (would be for actual DEX)
        vm.prank(user);
        weth.approve(address(this), swapAmount);
        
        // Simulate the swap by dealing USDC and reducing WETH
        vm.startPrank(user);
        weth.transfer(address(0xdead), swapAmount); // Burn WETH to simulate swap
        vm.stopPrank();
        
        // Deal USDC to simulate swap result
        deal(MAINNET_USDC, user, usdcReceived);
        
        // Verify final balances
        assertEq(weth.balanceOf(user), wrapAmount - swapAmount, "WETH balance should be reduced");
        assertEq(IERC20(MAINNET_USDC).balanceOf(user), usdcReceived, "User should have USDC");
        
        console.log("User account setup complete:");
        console.log("- ETH balance:", user.balance);
        console.log("- WETH balance:", weth.balanceOf(user));
        console.log("- USDC balance:", IERC20(MAINNET_USDC).balanceOf(user));
    }

}
