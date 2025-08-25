// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

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

    // ============ State Variables ============
    
    /// @notice Underlying token address
    uint8 public underlyingDecimals;
    
    /// @notice Fee recipient address
    address public feeRecipient;
    
    /// @notice Fee rate in basis points (1 = 0.01%)
    uint256 public feeRate;
    
    /// @notice Maximum fee rate in basis points
    uint256 public constant MAX_FEE_RATE = 1000; // 10%
    
    /// @notice Option pool contract address
    address public optionPool;
    
    /// @notice Minimum deposit amount
    uint256 public minDeposit;
    
    /// @notice Maximum vault capacity
    uint256 public maxCapacity;
    
    /// @notice Whether deposits are paused
    bool public depositsPaused;
    
    /// @notice Whether withdrawals are paused
    bool public withdrawalsPaused;

    // ============ Modifiers ============
    
    modifier whenDepositsNotPaused() {
        require(!depositsPaused, "OptionPoolVault: deposits paused");
        _;
    }
    
    modifier whenWithdrawalsNotPaused() {
        require(!withdrawalsPaused, "OptionPoolVault: withdrawals paused");
        _;
    }
    
    modifier validFeeRate(uint256 _feeRate) {
        require(_feeRate <= MAX_FEE_RATE, "OptionPoolVault: fee rate too high");
        _;
    }

    // ============ Constructor ============
    
    /**
     * @dev Constructor for the OptionPoolVault
     * @param _underlying The underlying ERC20 token
     * @param _name The name of the vault token
     * @param _symbol The symbol of the vault token
     * @param _feeRecipient The address to receive fees
     * @param _feeRate The fee rate in basis points
     * @param _optionPool The option pool contract address
     */
    constructor(
        IERC20 _underlying,
        string memory _name,
        string memory _symbol,
        address _feeRecipient,
        uint256 _feeRate,
        address _optionPool
    ) ERC4626(_underlying) ERC20(_name, _symbol) Ownable(msg.sender) validFeeRate(_feeRate) {
        require(_feeRecipient != address(0), "OptionPoolVault: invalid fee recipient");
        require(_optionPool != address(0), "OptionPoolVault: invalid option pool");
        
        feeRecipient = _feeRecipient;
        feeRate = _feeRate;
        optionPool = _optionPool;
        
        // Set reasonable defaults based on underlying token decimals
        underlyingDecimals = IERC20Metadata(address(_underlying)).decimals();
        minDeposit = 10 ** underlyingDecimals; // 1 token minimum
        maxCapacity = type(uint256).max; // No limit by default
    }

    // ============ ERC4626 Overrides ============
    
    /**
     * @dev Override deposit to add custom logic
     */
    function deposit(uint256 assets, address receiver) 
        public 
        override 
        whenNotPaused 
        whenDepositsNotPaused 
        nonReentrant 
        returns (uint256 shares) 
    {
        require(assets >= minDeposit, "OptionPoolVault: deposit too small");
        require(totalAssets() + assets <= maxCapacity, "OptionPoolVault: exceeds capacity");
        
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
        whenDepositsNotPaused 
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
        whenWithdrawalsNotPaused 
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
        whenWithdrawalsNotPaused 
        nonReentrant 
        returns (uint256 assets) 
    {
        assets = super.redeem(shares, receiver, owner);
        
        // Additional logic for option pool integration can be added here
        _afterRedeem(assets, shares, receiver, owner);
        
        return assets;
    }

    // ============ Fee Management ============
    
    /**
     * @dev Calculate and collect fees on deposit/mint
     * @param assets The amount of assets being deposited
     * @return feeAmount The amount of fees collected
     */
    function _calculateAndCollectFees(uint256 assets) internal returns (uint256 feeAmount) {
        if (feeRate == 0) return 0;
        
        feeAmount = assets * feeRate / 10000;
        if (feeAmount > 0) {
            // Transfer fees to fee recipient
            IERC20(asset()).safeTransfer(feeRecipient, feeAmount);
            emit FeeCollected(msg.sender, feeAmount);
        }
        
        return feeAmount;
    }
    
    /**
     * @dev Update fee recipient (owner only)
     * @param _newFeeRecipient The new fee recipient address
     */
    function updateFeeRecipient(address _newFeeRecipient) external onlyOwner {
        require(_newFeeRecipient != address(0), "OptionPoolVault: invalid fee recipient");
        address oldRecipient = feeRecipient;
        feeRecipient = _newFeeRecipient;
        emit FeeRecipientUpdated(oldRecipient, _newFeeRecipient);
    }
    
    /**
     * @dev Update fee rate (owner only)
     * @param _newFeeRate The new fee rate in basis points
     */
    function updateFeeRate(uint256 _newFeeRate) external onlyOwner validFeeRate(_newFeeRate) {
        uint256 oldRate = feeRate;
        feeRate = _newFeeRate;
        emit FeeRateUpdated(oldRate, _newFeeRate);
    }

    // ============ Vault Configuration ============
    
    /**
     * @dev Update option pool address (owner only)
     * @param _newOptionPool The new option pool address
     */
    function updateOptionPool(address _newOptionPool) external onlyOwner {
        require(_newOptionPool != address(0), "OptionPoolVault: invalid option pool");
        address oldPool = optionPool;
        optionPool = _newOptionPool;
        emit OptionPoolUpdated(oldPool, _newOptionPool);
    }
    
    /**
     * @dev Update minimum deposit amount (owner only)
     * @param _newMinDeposit The new minimum deposit amount
     */
    function updateMinDeposit(uint256 _newMinDeposit) external onlyOwner {
        minDeposit = _newMinDeposit;
    }
    
    /**
     * @dev Update maximum vault capacity (owner only)
     * @param _newMaxCapacity The new maximum capacity
     */
    function updateMaxCapacity(uint256 _newMaxCapacity) external onlyOwner {
        maxCapacity = _newMaxCapacity;
    }

    // ============ Pause Functionality ============
    
    /**
     * @dev Pause deposits (owner only)
     */
    function pauseDeposits() external onlyOwner {
        depositsPaused = true;
    }
    
    /**
     * @dev Unpause deposits (owner only)
     */
    function unpauseDeposits() external onlyOwner {
        depositsPaused = false;
    }
    
    /**
     * @dev Pause withdrawals (owner only)
     */
    function pauseWithdrawals() external onlyOwner {
        withdrawalsPaused = true;
    }
    
    /**
     * @dev Unpause withdrawals (owner only)
     */
    function unpauseWithdrawals() external onlyOwner {
        withdrawalsPaused = false;
    }
    
    /**
     * @dev Pause all vault operations (owner only)
     */
    function pause() external onlyOwner {
        _pause();
    }
    
    /**
     * @dev Unpause all vault operations (owner only)
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    // ============ Emergency Functions ============
    
    /**
     * @dev Emergency withdraw for owner (bypasses normal withdrawal logic)
     * @param amount The amount to withdraw
     */
    function emergencyWithdraw(uint256 amount) external onlyOwner {
        require(amount <= totalAssets(), "OptionPoolVault: insufficient assets");
        IERC20(asset()).safeTransfer(owner(), amount);
        emit EmergencyWithdraw(owner(), amount);
    }
    
    /**
     * @dev Emergency pause all operations (owner only)
     */
    function emergencyPause() external onlyOwner {
        _pause();
        depositsPaused = true;
        withdrawalsPaused = true;
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
        utilizationRate_ = maxCapacity > 0 ? totalAssets_ * 10000 / maxCapacity : 0;
    }
    
    /**
     * @dev Check if vault is at capacity
     * @return True if vault is at or near capacity
     */
    function isAtCapacity() external view returns (bool) {
        return totalAssets() >= maxCapacity;
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
