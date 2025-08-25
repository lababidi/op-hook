// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/OptionPoolVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token with 6 decimals (like USDC)
contract MockERC20_6Decimals is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
    
    function decimals() public pure override returns (uint8) {
        return 6; // USDC-style decimals
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Mock ERC20 token with 8 decimals (like WBTC)
contract MockERC20_8Decimals is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
    
    function decimals() public pure override returns (uint8) {
        return 8; // WBTC-style decimals
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract OptionPoolVaultDifferentDecimalsTest is Test {
    OptionPoolVault public vault6Decimals;
    OptionPoolVault public vault8Decimals;
    MockERC20_6Decimals public underlying6Decimals;
    MockERC20_8Decimals public underlying8Decimals;
    address public optionPool = address(0x123);
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public feeRecipient = address(0x3);
    address public owner = address(this);
    
    uint256 public constant FEE_RATE = 100; // 1%
    
    function setUp() public {
        // Deploy tokens with different decimals
        underlying6Decimals = new MockERC20_6Decimals("USDC Mock", "USDC");
        underlying8Decimals = new MockERC20_8Decimals("WBTC Mock", "WBTC");
        
        // Deploy vaults
        vault6Decimals = new OptionPoolVault(
            underlying6Decimals,
            "USDC Vault",
            "vUSDC",
            feeRecipient,
            FEE_RATE,
            optionPool
        );
        
        vault8Decimals = new OptionPoolVault(
            underlying8Decimals,
            "WBTC Vault",
            "vWBTC",
            feeRecipient,
            FEE_RATE,
            optionPool
        );
        
        // Fund test accounts
        underlying6Decimals.transfer(alice, 10000 * 10**6);
        underlying6Decimals.transfer(bob, 10000 * 10**6);
        underlying8Decimals.transfer(alice, 10000 * 10**8);
        underlying8Decimals.transfer(bob, 10000 * 10**8);
        
        // Fund vaults with initial liquidity
        underlying6Decimals.transfer(address(vault6Decimals), 1000 * 10**6);
        underlying8Decimals.transfer(address(vault8Decimals), 1000 * 10**8);
        
        // Unpause deposits for testing
        vault6Decimals.unpauseDeposits();
        vault8Decimals.unpauseDeposits();
    }

    function test_6DecimalTokenHandling() public {
        // Test 6-decimal token (like USDC)
        assertEq(vault6Decimals.underlyingDecimals(), 6);
        assertEq(vault6Decimals.minDeposit(), 10**6); // 1 USDC
        
        // Test deposit
        uint256 depositAmount = 100 * 10**6; // 100 USDC
        vm.startPrank(alice);
        underlying6Decimals.approve(address(vault6Decimals), depositAmount);
        
        uint256 shares = vault6Decimals.deposit(depositAmount, alice);
        assertGt(shares, 0);
        
        // Test withdrawal
        uint256 withdrawAmount = 50 * 10**6; // 50 USDC
        uint256 sharesBurned = vault6Decimals.withdraw(withdrawAmount, alice, alice);
        assertGt(sharesBurned, 0);
        vm.stopPrank();
    }

    function test_8DecimalTokenHandling() public {
        // Test 8-decimal token (like WBTC)
        assertEq(vault8Decimals.underlyingDecimals(), 8);
        assertEq(vault8Decimals.minDeposit(), 10**8); // 1 WBTC (in satoshis)
        
        // Test deposit
        uint256 depositAmount = 10 * 10**8; // 10 WBTC
        vm.startPrank(alice);
        underlying8Decimals.approve(address(vault8Decimals), depositAmount);
        
        uint256 shares = vault8Decimals.deposit(depositAmount, alice);
        assertGt(shares, 0);
        
        // Test withdrawal
        uint256 withdrawAmount = 5 * 10**8; // 5 WBTC
        uint256 sharesBurned = vault8Decimals.withdraw(withdrawAmount, alice, alice);
        assertGt(sharesBurned, 0);
        vm.stopPrank();
    }

    function test_DecimalConsistency() public {
        // Verify that the vault correctly handles different decimal tokens
        assertEq(vault6Decimals.underlyingDecimals(), 6);
        assertEq(vault8Decimals.underlyingDecimals(), 8);
        
        // Verify min deposit amounts are correct
        assertEq(vault6Decimals.minDeposit(), 10**6); // 1 USDC
        assertEq(vault8Decimals.minDeposit(), 10**8); // 1 WBTC
        
        // Test that small deposits are rejected
        vm.startPrank(alice);
        
        // Try to deposit less than 1 USDC
        underlying6Decimals.approve(address(vault6Decimals), 0.5 * 10**6);
        vm.expectRevert("OptionPoolVault: deposit too small");
        vault6Decimals.deposit(0.5 * 10**6, alice);
        
        // Try to deposit less than 1 WBTC
        underlying8Decimals.approve(address(vault8Decimals), 0.5 * 10**8);
        vm.expectRevert("OptionPoolVault: deposit too small");
        vault8Decimals.deposit(0.5 * 10**8, alice);
        
        vm.stopPrank();
    }

    function test_ExchangeRateConsistency() public {
        // Test that exchange rates work correctly with different decimals
        
        // 6-decimal token
        vm.startPrank(alice);
        uint256 depositAmount6 = 100 * 10**6; // 100 USDC
        underlying6Decimals.approve(address(vault6Decimals), depositAmount6);
        uint256 shares6 = vault6Decimals.deposit(depositAmount6, alice);
        
        (uint256 totalAssets6, uint256 totalShares6, uint256 exchangeRate6,) = vault6Decimals.getVaultStats();
        assertGt(exchangeRate6, 0);
        
        // 8-decimal token
        uint256 depositAmount8 = 10 * 10**8; // 10 WBTC
        underlying8Decimals.approve(address(vault8Decimals), depositAmount8);
        uint256 shares8 = vault8Decimals.deposit(depositAmount8, alice);
        
        (uint256 totalAssets8, uint256 totalShares8, uint256 exchangeRate8,) = vault8Decimals.getVaultStats();
        assertGt(exchangeRate8, 0);
        
        vm.stopPrank();
    }

    function test_ConversionFunctionsWithDifferentDecimals() public {
        // Test conversion functions work correctly with different decimals
        
        // 6-decimal token
        uint256 assets6 = 100 * 10**6; // 100 USDC
        uint256 shares6 = vault6Decimals.convertToShares(assets6);
        uint256 convertedAssets6 = vault6Decimals.convertToAssets(shares6);
        assertApproxEqRel(assets6, convertedAssets6, 0.01e18); // 1% tolerance
        
        // 8-decimal token
        uint256 assets8 = 10 * 10**8; // 10 WBTC
        uint256 shares8 = vault8Decimals.convertToShares(assets8);
        uint256 convertedAssets8 = vault8Decimals.convertToAssets(shares8);
        assertApproxEqRel(assets8, convertedAssets8, 0.01e18); // 1% tolerance
    }
}
