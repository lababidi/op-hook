// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title OptionPoolVault
 * @dev ERC4626 vault for managing option pool assets
 * 
 * This vault implements the ERC4626 standard for tokenized vaults with additional
 * functionality for option pool management. Users can deposit underlying tokens
 * and receive vault shares representing their proportional ownership.
 * 
 * Key features:
 * - ERC4626 compliant deposit/withdraw functionality
 * - Option pool integration
 * - Fee management
 * - Emergency pause functionality
 * - Access control for admin functions
 */
contract OptionPoolVault is ERC4626, Ownable, ReentrancyGuard, Pausable {
    using Math for uint256;
    using SafeERC20 for IERC20;

    // ============ Events ============
    
    event FeeCollected(address indexed from, uint256 amount);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event FeeRateUpdated(uint256 oldRate, uint256 newRate);
    event OptionPoolUpdated(address indexed oldPool, address indexed newPool);
    event EmergencyWithdraw(address indexed owner, uint256 amount);


    constructor(
        IERC20 _underlying,
        string memory _name,
        string memory _symbol
        // address _feeRecipient,
        // uint256 _feeRate,
        // address _optionPool
    ) ERC4626(_underlying) ERC20(_name, _symbol) Ownable(msg.sender) {
        
        
    }

    // ============ ERC4626 Overrides ============
    
    /**
     * @dev Override deposit to add custom logic
     */
    function deposit(uint256 assets, address receiver) 
        public 
        override 
        whenNotPaused 
        nonReentrant 
        returns (uint256 shares) 
    {
        
        shares = super.deposit(assets, receiver);
        
        // Additional logic for option pool integration can be added here
        _afterDeposit(assets, shares, receiver);
        
        return shares;
    }
    
    /**
     * @dev Override mint to add custom logic
     */
    function mint(uint256 shares, address receiver) 
        public 
        override 
        whenNotPaused 
        nonReentrant 
        returns (uint256 assets) 
    {
        require(shares > 0, "OptionPoolVault: zero shares");
        
        assets = super.mint(shares, receiver);
        
        // Additional logic for option pool integration can be added here
        _afterMint(assets, shares, receiver);
        
        return assets;
    }
    
    /**
     * @dev Override withdraw to add custom logic
     */
    function withdraw(uint256 assets, address receiver, address owner) 
        public 
        override 
        whenNotPaused 
        nonReentrant 
        returns (uint256 shares) 
    {
        shares = super.withdraw(assets, receiver, owner);
        
        // Additional logic for option pool integration can be added here
        _afterWithdraw(assets, shares, receiver, owner);
        
        return shares;
    }
    
    /**
     * @dev Override redeem to add custom logic
     */
    function redeem(uint256 shares, address receiver, address owner) 
        public 
        override 
        whenNotPaused 
        nonReentrant 
        returns (uint256 assets) 
    {
        assets = super.redeem(shares, receiver, owner);
        
        // Additional logic for option pool integration can be added here
        _afterRedeem(assets, shares, receiver, owner);
        
        return assets;
    }

    // ============ View Functions ============
    
    /**
     * @dev Get vault statistics
     * @return totalAssets_ Total assets in the vault
     * @return totalShares_ Total shares minted
     * @return exchangeRate_ Current exchange rate (assets per share)
     * @return utilizationRate_ Current utilization rate
     */
    function getVaultStats() external view returns (
        uint256 totalAssets_,
        uint256 totalShares_,
        uint256 exchangeRate_,
        uint256 utilizationRate_
    ) {
        totalAssets_ = totalAssets();
        totalShares_ = totalSupply();
        exchangeRate_ = totalShares_ > 0 ? totalAssets_ * 1e18 / totalShares_ : 1e18;
        utilizationRate_ =  0;
    }

    // ============ Internal Hooks ============
    
    /**
     * @dev Hook called after deposit
     * @param assets Amount of assets deposited
     * @param shares Amount of shares minted
     * @param receiver Address receiving the shares
     */
    function _afterDeposit(uint256 assets, uint256 shares, address receiver) internal virtual {
        // Override in child contracts to add custom logic
    }
    
    /**
     * @dev Hook called after mint
     * @param assets Amount of assets deposited
     * @param shares Amount of shares minted
     * @param receiver Address receiving the shares
     */
    function _afterMint(uint256 assets, uint256 shares, address receiver) internal virtual {
        // Override in child contracts to add custom logic
    }
    
    /**
     * @dev Hook called after withdraw
     * @param assets Amount of assets withdrawn
     * @param shares Amount of shares burned
     * @param receiver Address receiving the assets
     * @param owner Address that owned the shares
     */
    function _afterWithdraw(uint256 assets, uint256 shares, address receiver, address owner) internal virtual {
        // Override in child contracts to add custom logic
    }
    
    /**
     * @dev Hook called after redeem
     * @param assets Amount of assets withdrawn
     * @param shares Amount of shares burned
     * @param receiver Address receiving the assets
     * @param owner Address that owned the shares
     */
    function _afterRedeem(uint256 assets, uint256 shares, address receiver, address owner) internal virtual {
        // Override in child contracts to add custom logic
    }

    // ============ ERC4626 Required Overrides ============
    
    /**
     * @dev Override to implement custom conversion logic if needed
     */
    function _convertToShares(uint256 assets, Math.Rounding rounding) 
        internal 
        view 
        virtual 
        override 
        returns (uint256 shares) 
    {
        return super._convertToShares(assets, rounding);
    }
    
    /**
     * @dev Override to implement custom conversion logic if needed
     */
    function _convertToAssets(uint256 shares, Math.Rounding rounding) 
        internal 
        view 
        virtual 
        override 
        returns (uint256 assets) 
    {
        return super._convertToAssets(shares, rounding);
    }
    
    /**
     * @dev Override to implement custom deposit logic if needed
     */
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) 
        internal 
        virtual 
        override 
    {
        super._deposit(caller, receiver, assets, shares);
    }
    
    /**
     * @dev Override to implement custom withdraw logic if needed
     */
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares) 
        internal 
        virtual 
        override 
    {
        super._withdraw(caller, receiver, owner, assets, shares);
    }
}
