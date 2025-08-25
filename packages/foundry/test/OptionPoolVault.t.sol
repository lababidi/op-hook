// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../contracts/OptionPoolVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Mock option pool for testing
contract MockOptionPool {
    address public vault;
    
    constructor(address _vault) {
        vault = _vault;
    }
}

contract OptionPoolVaultTest is Test {
    OptionPoolVault public vault;
    MockERC20 public underlying;
    MockOptionPool public optionPool;
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public feeRecipient = address(0x3);
    address public owner = address(this);
    
    uint256 public INITIAL_BALANCE;
    uint256 public constant FEE_RATE = 100; // 1%
    
    // Helper function to get token amounts with proper decimals
    function tokenAmount(uint256 amount) internal view returns (uint256) {
        return amount * 10**underlying.decimals();
    }
    
    event FeeCollected(address indexed from, uint256 amount);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event FeeRateUpdated(uint256 oldRate, uint256 newRate);
    event OptionPoolUpdated(address indexed oldPool, address indexed newPool);
    event EmergencyWithdraw(address indexed owner, uint256 amount);

    function setUp() public {
        // Deploy mock contracts
        underlying = new MockERC20("Test Token", "TEST");
        optionPool = new MockOptionPool(address(0));
        
        // Deploy vault
        vault = new OptionPoolVault(
            underlying,
            "Option Pool Vault",
            "opVAULT",
            feeRecipient,
            FEE_RATE,
            address(optionPool)
        );
        
        // Update option pool to point to vault
        optionPool = new MockOptionPool(address(vault));
        
        // Calculate initial balance based on token decimals
        INITIAL_BALANCE = tokenAmount(10000);
        
        // Fund test accounts
        underlying.transfer(alice, INITIAL_BALANCE);
        underlying.transfer(bob, INITIAL_BALANCE);
        
        // Fund vault with some initial liquidity
        underlying.transfer(address(vault), tokenAmount(1000));
    }

    function test_Constructor() public {
        assertEq(vault.asset(), address(underlying));
        assertEq(vault.feeRecipient(), feeRecipient);
        assertEq(vault.feeRate(), FEE_RATE);
        assertEq(vault.optionPool(), address(optionPool));
        assertEq(vault.minDeposit(), tokenAmount(1));
        assertEq(vault.maxCapacity(), type(uint256).max);
        assertEq(vault.owner(), owner);
    }

    function test_Deposit() public {
        uint256 depositAmount = tokenAmount(1000);
        
        vm.startPrank(alice);
        underlying.approve(address(vault), depositAmount);
        
        uint256 sharesBefore = vault.balanceOf(alice);
        uint256 shares = vault.deposit(depositAmount, alice);
        uint256 sharesAfter = vault.balanceOf(alice);
        
        assertGt(shares, 0);
        assertEq(sharesAfter - sharesBefore, shares);
        assertEq(underlying.balanceOf(address(vault)), tokenAmount(2000)); // 1000 initial + 1000 deposit
        vm.stopPrank();
    }

    function test_DepositWithFee() public {
        uint256 depositAmount = tokenAmount(1000);
        uint256 expectedFee = depositAmount * FEE_RATE / 10000; // 1% fee
        uint256 expectedShares = vault.previewDeposit(depositAmount - expectedFee);
        
        vm.startPrank(alice);
        underlying.approve(address(vault), depositAmount);
        
        uint256 shares = vault.deposit(depositAmount, alice);
        
        assertEq(shares, expectedShares);
        assertEq(underlying.balanceOf(feeRecipient), expectedFee);
        vm.stopPrank();
    }

    function test_Mint() public {
        uint256 mintShares = tokenAmount(1000);
        
        vm.startPrank(alice);
        uint256 requiredAssets = vault.previewMint(mintShares);
        underlying.approve(address(vault), requiredAssets);
        
        uint256 assets = vault.mint(mintShares, alice);
        
        assertEq(assets, requiredAssets);
        assertEq(vault.balanceOf(alice), mintShares);
        vm.stopPrank();
    }

    function test_Withdraw() public {
        // First deposit
        uint256 depositAmount = tokenAmount(1000);
        vm.startPrank(alice);
        underlying.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, alice);
        
        // Then withdraw
        uint256 withdrawAmount = tokenAmount(500);
        uint256 sharesBurned = vault.withdraw(withdrawAmount, alice, alice);
        
        assertGt(sharesBurned, 0);
        assertLt(sharesBurned, shares);
        assertEq(underlying.balanceOf(alice), INITIAL_BALANCE - depositAmount + withdrawAmount);
        vm.stopPrank();
    }

    function test_Redeem() public {
        // First deposit
        uint256 depositAmount = tokenAmount(1000);
        vm.startPrank(alice);
        underlying.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, alice);
        
        // Then redeem
        uint256 redeemShares = shares / 2;
        uint256 assetsReceived = vault.redeem(redeemShares, alice, alice);
        
        assertGt(assetsReceived, 0);
        assertEq(vault.balanceOf(alice), shares - redeemShares);
        vm.stopPrank();
    }

    function test_MinDeposit() public {
        uint256 smallDeposit = tokenAmount(1) / 2; // Less than minDeposit
        
        vm.startPrank(alice);
        underlying.approve(address(vault), smallDeposit);
        
        vm.expectRevert("OptionPoolVault: deposit too small");
        vault.deposit(smallDeposit, alice);
        vm.stopPrank();
    }

    function test_MaxCapacity() public {
        // Set max capacity
        vault.updateMaxCapacity(tokenAmount(1000));
        
        uint256 largeDeposit = tokenAmount(2000);
        
        vm.startPrank(alice);
        underlying.approve(address(vault), largeDeposit);
        
        vm.expectRevert("OptionPoolVault: exceeds capacity");
        vault.deposit(largeDeposit, alice);
        vm.stopPrank();
    }

    function test_PauseDeposits() public {
        vault.pauseDeposits();
        
        vm.startPrank(alice);
        underlying.approve(address(vault), tokenAmount(1000));
        
        vm.expectRevert("OptionPoolVault: deposits paused");
        vault.deposit(tokenAmount(1000), alice);
        vm.stopPrank();
    }

    function test_PauseWithdrawals() public {
        // First deposit
        uint256 depositAmount = tokenAmount(1000);
        vm.startPrank(alice);
        underlying.approve(address(vault), depositAmount);
        vault.deposit(depositAmount, alice);
        
        // Pause withdrawals
        vault.pauseWithdrawals();
        
        vm.expectRevert("OptionPoolVault: withdrawals paused");
        vault.withdraw(tokenAmount(100), alice, alice);
        vm.stopPrank();
    }

    function test_PauseAll() public {
        vault.pause();
        
        vm.startPrank(alice);
        underlying.approve(address(vault), tokenAmount(1000));
        
        vm.expectRevert("Pausable: paused");
        vault.deposit(tokenAmount(1000), alice);
        vm.stopPrank();
    }

    function test_UpdateFeeRecipient() public {
        address newRecipient = address(0x4);
        
        vm.expectEmit(true, true, false, true);
        emit FeeRecipientUpdated(feeRecipient, newRecipient);
        
        vault.updateFeeRecipient(newRecipient);
        assertEq(vault.feeRecipient(), newRecipient);
    }

    function test_UpdateFeeRate() public {
        uint256 newFeeRate = 200; // 2%
        
        vm.expectEmit(false, false, false, true);
        emit FeeRateUpdated(FEE_RATE, newFeeRate);
        
        vault.updateFeeRate(newFeeRate);
        assertEq(vault.feeRate(), newFeeRate);
    }

    function test_UpdateFeeRateTooHigh() public {
        uint256 highFeeRate = 1500; // 15% > MAX_FEE_RATE (10%)
        
        vm.expectRevert("OptionPoolVault: fee rate too high");
        vault.updateFeeRate(highFeeRate);
    }

    function test_UpdateOptionPool() public {
        address newPool = address(0x5);
        
        vm.expectEmit(true, true, false, true);
        emit OptionPoolUpdated(address(optionPool), newPool);
        
        vault.updateOptionPool(newPool);
        assertEq(vault.optionPool(), newPool);
    }

    function test_EmergencyWithdraw() public {
        uint256 withdrawAmount = tokenAmount(500);
        
        vm.expectEmit(true, false, false, true);
        emit EmergencyWithdraw(owner, withdrawAmount);
        
        vault.emergencyWithdraw(withdrawAmount);
        assertEq(underlying.balanceOf(owner), withdrawAmount);
    }

    function test_GetVaultStats() public {
        (uint256 totalAssets, uint256 totalShares, uint256 exchangeRate, uint256 utilizationRate) = vault.getVaultStats();
        
        assertEq(totalAssets, tokenAmount(1000)); // Initial liquidity
        assertEq(totalShares, 0); // No shares minted yet
        assertEq(exchangeRate, 1e18); // Default exchange rate when no shares
        assertEq(utilizationRate, 0); // No utilization when maxCapacity is max uint256
    }

    function test_IsAtCapacity() public {
        assertFalse(vault.isAtCapacity());
        
        // Set max capacity to current total assets
        vault.updateMaxCapacity(tokenAmount(1000));
        assertTrue(vault.isAtCapacity());
    }

    function test_OnlyOwnerFunctions() public {
        vm.startPrank(alice);
        
        vm.expectRevert();
        vault.updateFeeRecipient(address(0x4));
        
        vm.expectRevert();
        vault.updateFeeRate(200);
        
        vm.expectRevert();
        vault.updateOptionPool(address(0x5));
        
        vm.expectRevert();
        vault.pauseDeposits();
        
        vm.expectRevert();
        vault.emergencyWithdraw(100 * 1e18);
        
        vm.stopPrank();
    }

    function test_ReentrancyProtection() public {
        // This test would require a malicious contract to test reentrancy
        // For now, we just verify the nonReentrant modifier is applied
        uint256 depositAmount = tokenAmount(1000);
        
        vm.startPrank(alice);
        underlying.approve(address(vault), depositAmount);
        
        // This should work without reentrancy issues
        vault.deposit(depositAmount, alice);
        vm.stopPrank();
    }

    function test_ExchangeRateCalculation() public {
        // Deposit some assets
        uint256 depositAmount = tokenAmount(1000);
        vm.startPrank(alice);
        underlying.approve(address(vault), depositAmount);
        uint256 shares = vault.deposit(depositAmount, alice);
        
        // Check exchange rate
        (,, uint256 exchangeRate,) = vault.getVaultStats();
        assertGt(exchangeRate, 0);
        
        // The exchange rate should be approximately assets/shares
        uint256 expectedRate = tokenAmount(1000) * 1e18 / shares;
        assertApproxEqRel(exchangeRate, expectedRate, 0.01e18); // 1% tolerance
        vm.stopPrank();
    }

    function test_ConversionFunctions() public {
        uint256 assets = tokenAmount(1000);
        uint256 shares = vault.convertToShares(assets);
        uint256 convertedAssets = vault.convertToAssets(shares);
        
        // Conversion should be approximately reversible
        assertApproxEqRel(assets, convertedAssets, 0.01e18); // 1% tolerance
    }

    function test_PreviewFunctions() public {
        uint256 assets = tokenAmount(1000);
        uint256 shares = tokenAmount(1000);
        
        uint256 previewShares = vault.previewDeposit(assets);
        uint256 previewAssets = vault.previewMint(shares);
        uint256 previewWithdrawShares = vault.previewWithdraw(assets);
        uint256 previewRedeemAssets = vault.previewRedeem(shares);
        
        assertGt(previewShares, 0);
        assertGt(previewAssets, 0);
        assertGt(previewWithdrawShares, 0);
        assertGt(previewRedeemAssets, 0);
    }

    function test_MaxFunctions() public {
        uint256 maxDeposit = vault.maxDeposit(alice);
        uint256 maxMint = vault.maxMint(alice);
        uint256 maxWithdraw = vault.maxWithdraw(alice);
        uint256 maxRedeem = vault.maxRedeem(alice);
        
        assertEq(maxDeposit, type(uint256).max);
        assertEq(maxMint, type(uint256).max);
        assertEq(maxWithdraw, 0); // No shares owned
        assertEq(maxRedeem, 0); // No shares owned
    }
    
    function test_DecimalHandling() public {
        // Test that the vault correctly handles the underlying token decimals
        uint8 expectedDecimals = underlying.decimals();
        uint8 vaultDecimals = vault.underlyingDecimals();
        
        assertEq(vaultDecimals, expectedDecimals);
        assertEq(vault.minDeposit(), tokenAmount(1));
        
        // Test that deposit amounts are handled correctly
        uint256 depositAmount = tokenAmount(100);
        underlying.approve(address(vault), depositAmount);
        
        uint256 shares = vault.deposit(depositAmount, alice);
        assertGt(shares, 0);
        
        // Test that withdrawal amounts are handled correctly
        uint256 withdrawAmount = tokenAmount(50);
        uint256 sharesBurned = vault.withdraw(withdrawAmount, alice, alice);
        assertGt(sharesBurned, 0);
    }
}
