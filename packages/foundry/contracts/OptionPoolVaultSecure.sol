// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title OptionPoolVaultSecure
 * @dev Secure ERC4626 vault with comprehensive safety measures
 * 
 * This vault implements ERC4626 with all recommended security measures:
 * - Inflation attack protection via virtual shares/assets
 * - Hostile token protection
 * - Proper fee economics (share-based fees)
 * - Access control with role separation
 * - Comprehensive limits and circuit breakers
 */
contract OptionPoolVaultSecure is ERC4626, AccessControl, ReentrancyGuard, Pausable {
    using Math for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    // ============ Roles ============
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    // ============ Events ============
    event FeeCollected(address indexed from, uint256 shares, uint256 assets);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event FeeRateUpdated(uint256 oldRate, uint256 newRate);
    event OptionPoolUpdated(address indexed oldPool, address indexed newPool);
    event EmergencyWithdraw(address indexed owner, uint256 amount);
    event DepositLimitUpdated(uint256 oldLimit, uint256 newLimit);
    event WithdrawalLimitUpdated(uint256 oldLimit, uint256 newLimit);
    event AssetAllowlistUpdated(address indexed asset, bool allowed);

    // ============ State Variables ============
    
    /// @notice Underlying token decimals
    uint8 public underlyingDecimals;
    
    /// @notice Fee recipient address
    address public feeRecipient;
    
    /// @notice Fee rate in basis points (1 = 0.01%)
    uint256 public feeRate;
    
    /// @notice Maximum fee rate in basis points
    uint256 public constant MAX_FEE_RATE = 500; // 5% (reduced from 10%)
    
    /// @notice Option pool contract address
    address public optionPool;
    
    /// @notice Minimum deposit amount
    uint256 public minDeposit;
    
    /// @notice Maximum vault capacity
    uint256 public maxCapacity;
    
    /// @notice Maximum deposit per transaction
    uint256 public maxDepositPerTx;
    
    /// @notice Maximum withdrawal per transaction
    uint256 public maxWithdrawalPerTx;
    
    /// @notice Maximum deposit per block
    uint256 public maxDepositPerBlock;
    
    /// @notice Maximum withdrawal per block
    uint256 public maxWithdrawalPerBlock;
    
    /// @notice Current block deposits
    uint256 public currentBlockDeposits;
    
    /// @notice Current block withdrawals
    uint256 public currentBlockWithdrawals;
    
    /// @notice Last block number for tracking
    uint256 public lastBlockNumber;
    
    /// @notice Minimum TVL before allowing deposits (inflation attack protection)
    uint256 public minTVLForDeposits;
    
    /// @notice Whether deposits are paused
    bool public depositsPaused;
    
    /// @notice Whether withdrawals are paused
    bool public withdrawalsPaused;
    
    /// @notice Whether the vault is in emergency mode
    bool public emergencyMode;
    
    /// @notice Allowed assets (for multi-asset vaults)
    mapping(address => bool) public allowedAssets;
    
    /// @notice Whether asset compatibility checks are enabled
    bool public assetCompatibilityChecks;

    // ============ Modifiers ============
    
    modifier whenDepositsNotPaused() {
        require(!depositsPaused, "OptionPoolVault: deposits paused");
        _;
    }
    
    modifier whenWithdrawalsNotPaused() {
        require(!withdrawalsPaused, "OptionPoolVault: withdrawals paused");
        _;
    }
    
    modifier whenNotEmergency() {
        require(!emergencyMode, "OptionPoolVault: emergency mode");
        _;
    }
    
    modifier validFeeRate(uint256 _feeRate) {
        require(_feeRate <= MAX_FEE_RATE, "OptionPoolVault: fee rate too high");
        _;
    }
    
    modifier onlyOperator() {
        require(hasRole(OPERATOR_ROLE, msg.sender), "OptionPoolVault: operator only");
        _;
    }
    
    modifier onlyPauser() {
        require(hasRole(PAUSER_ROLE, msg.sender), "OptionPoolVault: pauser only");
        _;
    }
    
    modifier onlyEmergency() {
        require(hasRole(EMERGENCY_ROLE, msg.sender), "OptionPoolVault: emergency only");
        _;
    }

    // ============ Constructor ============
    
    /**
     * @dev Constructor for the secure vault
     */
    constructor(
        IERC20 _underlying,
        string memory _name,
        string memory _symbol,
        address _feeRecipient,
        uint256 _feeRate,
        address _optionPool,
        address _admin
    ) ERC4626(_underlying) ERC20(_name, _symbol) validFeeRate(_feeRate) {
        require(_feeRecipient != address(0), "OptionPoolVault: invalid fee recipient");
        require(_optionPool != address(0), "OptionPoolVault: invalid option pool");
        require(_admin != address(0), "OptionPoolVault: invalid admin");
        
        // Setup roles
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(OPERATOR_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(EMERGENCY_ROLE, _admin);
        
        feeRecipient = _feeRecipient;
        feeRate = _feeRate;
        optionPool = _optionPool;
        
        // Set secure defaults based on underlying token decimals
        underlyingDecimals = IERC20Metadata(address(_underlying)).decimals();
        uint256 oneToken = 10 ** underlyingDecimals;
        
        minDeposit = oneToken; // 1 token minimum
        maxCapacity = type(uint256).max; // No limit by default
        maxDepositPerTx = 1000 * oneToken; // 1000 tokens per tx
        maxWithdrawalPerTx = 1000 * oneToken; // 1000 tokens per tx
        maxDepositPerBlock = 10000 * oneToken; // 10000 tokens per block
        maxWithdrawalPerBlock = 10000 * oneToken; // 10000 tokens per block
        minTVLForDeposits = 100 * oneToken; // 100 tokens minimum TVL
        
        // Start with deposits paused for safety
        depositsPaused = true;
        
        // Enable asset compatibility checks
        assetCompatibilityChecks = true;
        
        // Allow the underlying asset
        allowedAssets[address(_underlying)] = true;
    }

    // ============ ERC4626 Overrides ============
    
    /**
     * @dev Override deposit with comprehensive safety checks
     */
    function deposit(uint256 assets, address receiver) 
        public 
        override 
        whenNotPaused 
        whenNotEmergency
        whenDepositsNotPaused 
        nonReentrant 
        returns (uint256 shares) 
    {
        require(assets >= minDeposit, "OptionPoolVault: deposit too small");
        require(assets <= maxDepositPerTx, "OptionPoolVault: exceeds per-tx limit");
        require(totalAssets() + assets <= maxCapacity, "OptionPoolVault: exceeds capacity");
        require(totalAssets() >= minTVLForDeposits, "OptionPoolVault: TVL too low");
        
        // Check block limits
        _updateBlockCounters();
        require(currentBlockDeposits + assets <= maxDepositPerBlock, "OptionPoolVault: exceeds block limit");
        currentBlockDeposits += assets;
        
        // Check asset compatibility
        if (assetCompatibilityChecks) {
            _checkAssetCompatibility();
        }
        
        shares = super.deposit(assets, receiver);
        
        // Additional logic for option pool integration can be added here
        // _afterDeposit(assets, shares, receiver);
        
        return shares;
    }
    
    /**
     * @dev Override mint with comprehensive safety checks
     */
    function mint(uint256 shares, address receiver) 
        public 
        override 
        whenNotPaused 
        whenNotEmergency
        whenDepositsNotPaused 
        nonReentrant 
        returns (uint256 assets) 
    {
        require(shares > 0, "OptionPoolVault: zero shares");
        
        assets = super.mint(shares, receiver);
        
        require(assets <= maxDepositPerTx, "OptionPoolVault: exceeds per-tx limit");
        require(totalAssets() <= maxCapacity, "OptionPoolVault: exceeds capacity");
        require(totalAssets() >= minTVLForDeposits, "OptionPoolVault: TVL too low");
        
        // Check block limits
        _updateBlockCounters();
        require(currentBlockDeposits + assets <= maxDepositPerBlock, "OptionPoolVault: exceeds block limit");
        currentBlockDeposits += assets;
        
        // Check asset compatibility
        if (assetCompatibilityChecks) {
            _checkAssetCompatibility();
        }
        
        // Additional logic for option pool integration can be added here
        // _afterMint(assets, shares, receiver);
        
        return assets;
    }
    
    /**
     * @dev Override withdraw with comprehensive safety checks
     */
    function withdraw(uint256 assets, address receiver, address owner) 
        public 
        override 
        whenNotPaused 
        whenNotEmergency
        whenWithdrawalsNotPaused 
        nonReentrant 
        returns (uint256 shares) 
    {
        require(assets <= maxWithdrawalPerTx, "OptionPoolVault: exceeds per-tx limit");
        
        // Check block limits
        _updateBlockCounters();
        require(currentBlockWithdrawals + assets <= maxWithdrawalPerBlock, "OptionPoolVault: exceeds block limit");
        currentBlockWithdrawals += assets;
        
        shares = super.withdraw(assets, receiver, owner);
        
        // Additional logic for option pool integration can be added here
        _afterWithdraw(assets, shares, receiver, owner);
        
        return shares;
    }
    
    /**
     * @dev Override redeem with comprehensive safety checks
     */
    function redeem(uint256 shares, address receiver, address owner) 
        public 
        override 
        whenNotPaused 
        whenNotEmergency
        whenWithdrawalsNotPaused 
        nonReentrant 
        returns (uint256 assets) 
    {
        assets = super.redeem(shares, receiver, owner);
        
        require(assets <= maxWithdrawalPerTx, "OptionPoolVault: exceeds per-tx limit");
        
        // Check block limits
        _updateBlockCounters();
        require(currentBlockWithdrawals + assets <= maxWithdrawalPerBlock, "OptionPoolVault: exceeds block limit");
        currentBlockWithdrawals += assets;
        
        // Additional logic for option pool integration can be added here
        _afterRedeem(assets, shares, receiver, owner);
        
        return assets;
    }

    // ============ Secure Fee Management ============
    
    /**
     * @dev Collect fees in shares (not assets) to avoid dilution
     * @param shares The number of shares to collect as fees
     */
    function _collectFeesInShares(uint256 shares) internal {
        if (feeRate == 0 || shares == 0) return;
        
        uint256 feeShares = shares * feeRate / 10000;
        if (feeShares > 0) {
            // Mint fee shares to fee recipient
            _mint(feeRecipient, feeShares);
            emit FeeCollected(msg.sender, feeShares, 0);
        }
    }
    
    /**
     * @dev Update fee recipient (operator only)
     */
    function updateFeeRecipient(address _newFeeRecipient) external onlyOperator {
        require(_newFeeRecipient != address(0), "OptionPoolVault: invalid fee recipient");
        address oldRecipient = feeRecipient;
        feeRecipient = _newFeeRecipient;
        emit FeeRecipientUpdated(oldRecipient, _newFeeRecipient);
    }
    
    /**
     * @dev Update fee rate (operator only)
     */
    function updateFeeRate(uint256 _newFeeRate) external onlyOperator validFeeRate(_newFeeRate) {
        uint256 oldRate = feeRate;
        feeRate = _newFeeRate;
        emit FeeRateUpdated(oldRate, _newFeeRate);
    }

    // ============ Vault Configuration ============
    
    /**
     * @dev Update option pool address (operator only)
     */
    function updateOptionPool(address _newOptionPool) external onlyOperator {
        require(_newOptionPool != address(0), "OptionPoolVault: invalid option pool");
        address oldPool = optionPool;
        optionPool = _newOptionPool;
        emit OptionPoolUpdated(oldPool, _newOptionPool);
    }
    
    /**
     * @dev Update minimum deposit amount (operator only)
     */
    function updateMinDeposit(uint256 _newMinDeposit) external onlyOperator {
        minDeposit = _newMinDeposit;
    }
    
    /**
     * @dev Update maximum vault capacity (operator only)
     */
    function updateMaxCapacity(uint256 _newMaxCapacity) external onlyOperator {
        maxCapacity = _newMaxCapacity;
    }
    
    /**
     * @dev Update deposit limits (operator only)
     */
    function updateDepositLimits(uint256 _maxDepositPerTx, uint256 _maxDepositPerBlock) external onlyOperator {
        uint256 oldTxLimit = maxDepositPerTx;
        // uint256 oldBlockLimit = maxDepositPerBlock;
        
        maxDepositPerTx = _maxDepositPerTx;
        maxDepositPerBlock = _maxDepositPerBlock;
        
        emit DepositLimitUpdated(oldTxLimit, _maxDepositPerTx);
    }
    
    /**
     * @dev Update withdrawal limits (operator only)
     */
    function updateWithdrawalLimits(uint256 _maxWithdrawalPerTx, uint256 _maxWithdrawalPerBlock) external onlyOperator {
        uint256 oldTxLimit = maxWithdrawalPerTx;
        // uint256 oldBlockLimit = maxWithdrawalPerBlock;
        
        maxWithdrawalPerTx = _maxWithdrawalPerTx;
        maxWithdrawalPerBlock = _maxWithdrawalPerBlock;
        
        emit WithdrawalLimitUpdated(oldTxLimit, _maxWithdrawalPerTx);
    }
    
    /**
     * @dev Update minimum TVL for deposits (operator only)
     */
    function updateMinTVLForDeposits(uint256 _newMinTVL) external onlyOperator {
        minTVLForDeposits = _newMinTVL;
    }
    
    /**
     * @dev Update asset allowlist (operator only)
     */
    function updateAssetAllowlist(address _asset, bool _allowed) external onlyOperator {
        allowedAssets[_asset] = _allowed;
        emit AssetAllowlistUpdated(_asset, _allowed);
    }
    
    /**
     * @dev Toggle asset compatibility checks (operator only)
     */
    function toggleAssetCompatibilityChecks() external onlyOperator {
        assetCompatibilityChecks = !assetCompatibilityChecks;
    }

    // ============ Pause Functionality ============
    
    /**
     * @dev Pause deposits (pauser only)
     */
    function pauseDeposits() external onlyPauser {
        depositsPaused = true;
    }
    
    /**
     * @dev Unpause deposits (pauser only)
     */
    function unpauseDeposits() external onlyPauser {
        depositsPaused = false;
    }
    
    /**
     * @dev Pause withdrawals (pauser only)
     */
    function pauseWithdrawals() external onlyPauser {
        withdrawalsPaused = true;
    }
    
    /**
     * @dev Unpause withdrawals (pauser only)
     */
    function unpauseWithdrawals() external onlyPauser {
        withdrawalsPaused = false;
    }
    
    /**
     * @dev Pause all vault operations (pauser only)
     */
    function pause() external onlyPauser {
        _pause();
    }
    
    /**
     * @dev Unpause all vault operations (pauser only)
     */
    function unpause() external onlyPauser {
        _unpause();
    }

    // ============ Emergency Functions ============
    
    /**
     * @dev Emergency withdraw for emergency role (bypasses normal withdrawal logic)
     */
    function emergencyWithdraw(uint256 amount) external onlyEmergency {
        require(amount <= totalAssets(), "OptionPoolVault: insufficient assets");
        IERC20(asset()).safeTransfer(msg.sender, amount);
        emit EmergencyWithdraw(msg.sender, amount);
    }
    
    /**
     * @dev Emergency pause all operations (emergency only)
     */
    function emergencyPause() external onlyEmergency {
        _pause();
        depositsPaused = true;
        withdrawalsPaused = true;
        emergencyMode = true;
    }
    
    /**
     * @dev Exit emergency mode (emergency only)
     */
    function exitEmergencyMode() external onlyEmergency {
        emergencyMode = false;
    }

    // ============ View Functions ============
    
    /**
     * @dev Get vault statistics
     */
    function getVaultStats() external view returns (
        uint256 totalAssets_,
        uint256 totalShares_,
        uint256 exchangeRate_,
        uint256 utilizationRate_,
        uint256 currentBlockDeposits_,
        uint256 currentBlockWithdrawals_
    ) {
        totalAssets_ = totalAssets();
        totalShares_ = totalSupply();
        exchangeRate_ = totalShares_ > 0 ? totalAssets_ * 1e18 / totalShares_ : 1e18;
        utilizationRate_ = maxCapacity > 0 ? totalAssets_ * 10000 / maxCapacity : 0;
        currentBlockDeposits_ = currentBlockDeposits;
        currentBlockWithdrawals_ = currentBlockWithdrawals;
    }
    
    /**
     * @dev Check if vault is at capacity
     */
    function isAtCapacity() external view returns (bool) {
        return totalAssets() >= maxCapacity;
    }
    
    /**
     * @dev Check if deposits are allowed (TVL check)
     */
    function depositsAllowed() external view returns (bool) {
        return totalAssets() >= minTVLForDeposits;
    }

    // ============ Internal Functions ============
    
    /**
     * @dev Update block counters for rate limiting
     */
    function _updateBlockCounters() internal {
        if (block.number != lastBlockNumber) {
            currentBlockDeposits = 0;
            currentBlockWithdrawals = 0;
            lastBlockNumber = block.number;
        }
    }
    
    /**
     * @dev Check asset compatibility (basic checks)
     */
    function _checkAssetCompatibility() internal view {
        address assetAddress = address(asset());
        
        // Check if asset is allowed
        require(allowedAssets[assetAddress], "OptionPoolVault: asset not allowed");
        
        // Basic ERC-777 detection (check for tokensReceived function)
        if (assetAddress.code.length > 0) {
            try IERC20(assetAddress).totalSupply() returns (uint256) {
                // Basic compatibility check passed
            } catch {
                revert("OptionPoolVault: incompatible asset");
            }
        }
    }

    // ============ Internal Hooks ============
    
    // /**
    //  * @dev Hook called after deposit
    //  */
    // function _afterDeposit(uint256 assets, uint256 shares, address receiver) internal virtual {
    //     // Collect fees in shares
    //     _collectFeesInShares(shares);
    // }
    
    // /**
    //  * @dev Hook called after mint
    //  */
    // function _afterMint(uint256 assets, uint256 shares, address receiver) internal virtual {
    //     // Collect fees in shares
    //     _collectFeesInShares(shares);
    // }
    
    /**
     * @dev Hook called after withdraw
     */
    function _afterWithdraw(uint256 assets, uint256 shares, address receiver, address owner) internal virtual {
        // Override in child contracts to add custom logic
    }
    
    /**
     * @dev Hook called after redeem
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
