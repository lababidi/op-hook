// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "@openzeppelin/uniswap-hooks/src/base/BaseHook.sol";

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager, SwapParams} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BeforeSwapDelta, toBeforeSwapDelta} from "v4-core/src/types/BeforeSwapDelta.sol";
import {Currency} from "v4-core/src/types/Currency.sol";

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {OptionPrice, PriceMath, IUniswapV3Pool} from "./OptionPrice.sol";

import {IOptionToken} from "./IOptionToken.sol";
import {IPermit2} from "./IPermit2.sol";

import {IHooks} from "v4-core/src/interfaces/IHooks.sol";

uint160 constant SQRT_PRICE_X96 = 1<<96;
int24 constant TICK_SPACING = 1;

struct OptionPool {
    address underlying;
    address token0;
    address token1;
    uint24 fee;
    int24 tickSpacing;
    uint160 sqrtPriceX96;
    address optionToken;
    uint256 expiration;
}

struct CurrentOptionPrice {
    address underlying;
    address optionToken;
    uint256 price;
    uint256 collateralPrice;
}

contract OpHook is BaseHook, ERC4626, Ownable, ReentrancyGuard, Pausable {
    using PoolIdLibrary for PoolKey;


    using Math for uint256;
    using SafeERC20 for IERC20;

    // ============ Events ============
    
    event FeeCollected(address indexed from, uint256 amount);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event FeeRateUpdated(uint256 oldRate, uint256 newRate);
    event OptionPoolUpdated(address indexed oldPool, address indexed newPool);
    event EmergencyWithdraw(address indexed owner, uint256 amount);

    OptionPrice public optionPrice;
    IERC20 public underlying;
    address public pricePool;
    address public cash;
    bool public zeroOrOne;

    IPermit2 public immutable PERMIT2;

    mapping(address => bool) public options;
    OptionPool[] public pools;
    PriceMath priceMath;

    constructor(IPoolManager _poolManager, address permit2, IERC20 _underlying, string memory _name, string memory _symbol, address _pricePool) 
    BaseHook(_poolManager) 
    ERC4626(_underlying) 
    ERC20(_name, _symbol) 
    Ownable(msg.sender) {
        optionPrice = new OptionPrice(_pricePool);
        PERMIT2 = IPermit2(permit2);
        underlying = _underlying;
        pricePool = _pricePool;
        cash = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        zeroOrOne = address(underlying) > address(cash);
        priceMath = new PriceMath();
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory permissions) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: true,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function _beforeSwap(address, PoolKey calldata key, SwapParams calldata params, bytes calldata)
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24){

        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);
        address option_;
        if (options[token1]){
            option_ = token1;
        } else if (options[token0]){
            option_ = token0;
        } else {
            revert("Token not whitelisted");
        }
        IOptionToken option = IOptionToken(option_);
        require(params.amountSpecified < 0, "amountSpecified must be negative");
        uint256 amount = uint256(-params.amountSpecified);
        int128 amount_ = int128(int256(amount));
        uint256 collateralPrice = priceMath.getPrice(IUniswapV3Pool(pricePool), zeroOrOne);
        if (params.zeroForOne) {
            
            uint256 price = optionPrice.getPrice(collateralPrice, option.strike(), option.expirationDate(), option.isPut(), false);
            uint256 collateralAmount = (amount * price) / 1e18;
            int128 collateralAmount_ = int128(int256(collateralAmount));
            require(collateralAmount <= option.balanceOf(address(this)), "Insufficient optionToken balance");

            option.mint(collateralAmount);
            BeforeSwapDelta delta = toBeforeSwapDelta(-amount_, collateralAmount_);
            poolManager.mint(address(this), key.currency0.toId(), amount);
            poolManager.burn(address(this), key.currency1.toId(), collateralAmount);
            return (BaseHook.beforeSwap.selector, delta, 0);
        } else {
            uint256 price = optionPrice.getPrice(collateralPrice, option.strike(), option.expirationDate(), option.isPut(), true);
            uint256 tokenBAmount = Math.mulDiv(amount, price, 1e18);
            int128 tokenBAmount_ = int128(int256(tokenBAmount));
            BeforeSwapDelta delta = toBeforeSwapDelta(tokenBAmount_, -amount_);
            poolManager.mint(address(this), key.currency1.toId(), amount);
            poolManager.burn(address(this), key.currency0.toId(), tokenBAmount);
            poolManager.settle();
            option.redeem(amount);
            return (BaseHook.beforeSwap.selector, delta, 0);
        }
    }

    function _beforeAddLiquidity(address, PoolKey calldata key, SwapParams calldata params, bytes calldata)
        internal
        pure
        
        returns (bytes4, BeforeSwapDelta, uint24){
            revert("Cannot Add Liquidity to This Pool ");
        }

    function _beforeDonate(address, PoolKey calldata key, SwapParams calldata params, bytes calldata)
        internal
        pure
        returns (bytes4, BeforeSwapDelta, uint24){
            revert("Cannot Donate to This Pool");
        }



    function getPools() public view returns (OptionPool[] memory) {
        return pools;
    }

    function getPrices() public view returns (uint256[] memory) {
        uint256[] memory prices = new uint256[](pools.length);
        uint256 collateralPrice = priceMath.getPrice(IUniswapV3Pool(pricePool), zeroOrOne);
        for (uint256 i = 0; i < pools.length; i++) {
            OptionPool memory pool = pools[i];
            IOptionToken option = IOptionToken(pool.optionToken);
            prices[i] = optionPrice.getPrice(collateralPrice, option.strike(), option.expirationDate(), option.isPut(), false);
        }
        return prices;
    }

    function _getOptionPrice(address optionToken, bool inverse) internal view returns (uint256) {
        IOptionToken option = IOptionToken(optionToken);
        uint256 collateralPrice = priceMath.getPrice(IUniswapV3Pool(pricePool), zeroOrOne);
        return optionPrice.getPrice(collateralPrice, option.strike(), option.expirationDate(), option.isPut(), inverse);
    }

    function getOptionPrice(address optionToken) public view returns (CurrentOptionPrice memory) {
        IOptionToken option = IOptionToken(optionToken);
        uint256 collateralPrice = priceMath.getPrice(IUniswapV3Pool(pricePool), zeroOrOne);

        uint256 price = optionPrice.getPrice(collateralPrice, option.strike(), option.expirationDate(), option.isPut(), false);
        return CurrentOptionPrice({
            collateralPrice: collateralPrice,
            underlying: address(underlying),
            optionToken: optionToken,
            price: price
        });
    }
    function initPool(
        address optionToken,
        address cash_,
        uint24 fee
    ) public {

        IOptionToken optionToken_ = IOptionToken(optionToken);
        uint256 expiration = optionToken_.expirationDate();
        address token0 = cash_ < optionToken ? cash_ : optionToken;
        address token1 = cash_ < optionToken ? optionToken : cash_;

        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: fee,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(this))
        });
        poolManager.initialize(poolKey, SQRT_PRICE_X96);

        OptionPool memory pool = OptionPool({
            underlying: address(underlying),
            token0: token0,
            token1: token1,
            fee: fee,
            tickSpacing: TICK_SPACING,
            sqrtPriceX96: SQRT_PRICE_X96,  //todo: verify this
            optionToken: optionToken,
            expiration: expiration
        });
        pools.push(pool);
        

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
