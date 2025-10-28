// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "@openzeppelin/uniswap-hooks/src/base/BaseHook.sol";

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager, SwapParams} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BeforeSwapDelta, toBeforeSwapDelta} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {SafeCast} from "@uniswap/v4-core/src/libraries/SafeCast.sol";

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";


import {OptionPrice, IUniswapV3Pool} from "./OptionPrice.sol";

import {IOptionToken} from "./IOptionToken.sol";
import {IPermit2} from "./IPermit2.sol";

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {console} from "forge-std/console.sol";

uint160 constant SQRT_PRICE_X96 = 1<<96;
int24 constant TICK_SPACING = type(int16).max;

struct OptionPool {
    address collateral;
    address pricePool;
    bool collateralIsOne;

    address optionToken;
    address cashToken;
    bool optionIsOne;
    uint24 fee;
    int24 tickSpacing;
    uint160 sqrtPriceX96;
    uint256 expiration;
    uint256 strike;
}

struct CurrentOptionPrice {
    address collateral;
    address optionToken;
    uint256 price;
    uint256 collateralPrice;
}


struct Price {
    uint256 optionAmount;
    uint256 cashAmount;
    uint256 collateralPrice;
    uint256 price;
}

contract OpHook is BaseHook, Ownable, ReentrancyGuard, Pausable {
    using PoolIdLibrary for PoolKey;
    using Math for uint256;
    using SafeERC20 for IERC20;
    using SafeERC20 for IOptionToken;

    // ============ Events ============
    
    event FeeCollected(address indexed from, uint256 amount);
    event FeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);
    event FeeRateUpdated(uint256 oldRate, uint256 newRate);
    event OptionPoolUpdated(address indexed oldPool, address indexed newPool);
    event EmergencyWithdraw(address indexed owner, uint256 amount);
    event Swap(address, address, int256, uint256);

    OptionPrice public optionPrice;

    IPermit2 public immutable PERMIT2;
    address public pm;

    OptionPool[] public allPools;
    mapping(address => mapping(address => OptionPool)) public optionCashPool;
    mapping(bytes32 => OptionPool) public optionPools;
    mapping(address => OptionPool[]) public collateralPools;
    mapping(address => IUniswapV3Pool) public collateralPricePool;
    mapping(address => bool) public cash;
    mapping(address => bool) public validOptions;
    mapping(address => OptionPool[]) public optionPoolList;

    modifier validCash(address cash_) {
        require(cash[cash_], "Invalid cash address");
        _;
    }
    modifier validOption(address option_) {
        require(optionPoolList[option_].length > 0, "Invalid option address");
        _;
    }

    constructor(IPoolManager _poolManager, address permit2) 
    BaseHook(_poolManager) 
    Ownable(msg.sender) {
        optionPrice = new OptionPrice();
        PERMIT2 = IPermit2(permit2);
        pm = address(_poolManager);

    }

    function toId(PoolKey memory k) internal pure returns (bytes32) {
        // make sure currency0 < currency1 is already enforced when constructing k
        // prefer abi.encode (not encodePacked) to avoid any theoretical collisions
        return keccak256(abi.encode(
            Currency.unwrap(k.currency0),
            Currency.unwrap(k.currency1),
            k.fee,
            k.tickSpacing,
            k.hooks
        ));
    }

    function addCash(address _cash) external onlyOwner {
        cash[_cash] = true;
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
            beforeSwapReturnDelta: true,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function to128(uint256 x) internal pure returns (int128 y) {
        return SafeCast.toInt128(int256(x));
    }

    function abs(int256 x) internal pure returns (uint256) {
        return uint256(x < 0 ? -x : x);
    }

    function calculateOption(address collateral, address option, int256 cashAmount) internal view returns (Price memory amounts){
        uint256 collateralPrice = getCollateralPrice(collateral);
        uint256 price = getPrice(collateralPrice, option);

        amounts = Price({
            collateralPrice:collateralPrice,
            price:price,
            optionAmount: calculateOption(abs(cashAmount), price),
            cashAmount: abs(cashAmount)
            }
        );
    }

    function calculateCash(address collateral, address option, int256 optionAmount) internal view returns (Price memory amounts){
        uint256 collateralPrice = getCollateralPrice(collateral);
        uint256 price = getPrice(collateralPrice, option);
        
        amounts = Price({
            collateralPrice:collateralPrice,
            price:price,
            optionAmount: abs(optionAmount),
            cashAmount: calculateCash(abs(optionAmount), price)
            }
        );
    }

    function availableCollateral(address collateral) external view returns (uint256){
        return IERC20(collateral).balanceOf(address(this));
    }

    function calculateOption(uint256 cashAmount, uint256 price) public pure returns (uint256){
        return Math.mulDiv(cashAmount, 1e18, price);
    }

    function calculateCash(uint256 optionAmount, uint256 price) public pure returns (uint256){
        return Math.mulDiv(optionAmount, price, 1e18);
    }

    function transferCash(address cash_, uint256 cashAmount) internal returns (uint256 cashTransferred){
        IERC20  _cash = IERC20(cash_);
        uint256 initialCash = _cash.balanceOf(address(this));
        _cash.safeTransferFrom(msg.sender, address(this), cashAmount);
        cashTransferred = _cash.balanceOf(address(this)) - initialCash;
        require(cashTransferred > 0, "No Cash Transferred in");
    }

    function collateralBalance(address collateral) public view returns (uint256){
        return IERC20(collateral).balanceOf(address(this));
    }


    function swapForOption(address optionToken, address cashToken, int256 amount, address to) public nonReentrant validCash(cashToken) validOption(optionToken) {
        require(to != address(0), "bad to");
        IOptionToken option = IOptionToken(optionToken);
        address collateral = address(option.collateral());

        Price memory p = calculateCash(collateral, optionToken, -int256(amount));

        transferCash(cashToken, p.cashAmount);
        option.mint(p.optionAmount);
        option.safeTransfer(to, p.optionAmount);

        emit Swap(msg.sender, to, amount, p.price);
    }

    function swapForOption(address optionToken, address cashToken, int256 cashAmount) public nonReentrant validCash(cashToken) {
        swapForOption(optionToken, cashToken, cashAmount, msg.sender);
        }

    function _beforeSwap(address, PoolKey calldata key, SwapParams calldata params, bytes calldata)
        internal
        override
        returns (bytes4 selector, BeforeSwapDelta delta, uint24 zeroReturn){
        require(params.amountSpecified < 0, "amountSpecified must be negative");
        zeroReturn = 0;
        selector = BaseHook.beforeSwap.selector;

        OptionPool memory pool = optionPools[toId(key)];
        bool cashForOption = pool.optionIsOne ? params.zeroForOne : !params.zeroForOne;
        Currency cashCurrency = pool.optionIsOne ? key.currency0 : key.currency1;
        Currency optionCurrency = pool.optionIsOne ? key.currency1 : key.currency0;
        Price memory a = calculateCash(
            pool.collateral, 
            pool.optionToken, 
            params.amountSpecified
            );
        IOptionToken option = IOptionToken(pool.optionToken);
        require(option.expirationDate() > block.timestamp, "Option expired");

        if (cashForOption) {
            // Here we JIT create option tokens and let the flash accounting handle transfers
            option.mint(a.optionAmount);
            poolManager.take(cashCurrency, address(this), a.cashAmount);
            poolManager.sync(optionCurrency);
            option.safeTransfer(pm, a.optionAmount);
            poolManager.settle();
            delta = toBeforeSwapDelta(to128(a.cashAmount), -to128(a.optionAmount));
        } else {
            // Here we have to take the option tokens from the caller and burn them
            poolManager.take(optionCurrency, address(this), a.optionAmount);
            poolManager.sync(cashCurrency);
            IERC20(pool.cashToken).safeTransfer(pm, a.cashAmount);
            poolManager.settle();
            option.redeem(a.optionAmount);
            delta = toBeforeSwapDelta( to128(a.optionAmount), -to128(a.cashAmount));
        }
    }

    function _beforeAddLiquidity(address, PoolKey calldata, SwapParams calldata, bytes calldata)
        internal
        pure
        
        returns (bytes4, BeforeSwapDelta, uint24){
            revert("Cannot Add Liquidity to This Pool ");
        }

    function _beforeDonate(address, PoolKey calldata, SwapParams calldata, bytes calldata) internal pure returns (bytes4, BeforeSwapDelta, uint24){
            revert("Cannot Donate to This Pool");
        }

    
    function getPriceX64(uint160 sqrtPriceX96) public pure returns (uint256) {
        uint256 sqrtPriceX32 = (uint256(sqrtPriceX96)>>64);
        // priceX96 is Q64.96, so we square to get the ratio
        return uint256(sqrtPriceX32) * uint256(sqrtPriceX32);
    }

    // Returns price of 1 token0 in token1 with 18 decimals precision
    // How much token1 you need to buy 1 token0 is sqrtPriceX96
    function getCollateralPrice(address collateral) public view returns (uint256 price) {

        IUniswapV3Pool pricePool = IUniswapV3Pool(collateralPricePool[collateral]);

        bool collateralIsOne = pricePool.token0() == collateral ? pricePool.token1() == collateral : pricePool.token0() == collateral;
        uint8 decimals0 = IERC20Metadata(pricePool.token0()).decimals();
        uint8 decimals1 = IERC20Metadata(pricePool.token1()).decimals();
        uint256 power = 10 ** (decimals1 >= decimals0 ? decimals1 - decimals0 : decimals0 - decimals1);

        (uint160 sqrtPriceX96,,,,,,) = pricePool.slot0();
        // Calculate price with proper scaling
        // priceX192 is in Q192.192 format, we need to extract the integer part
        // uint256 priceX96 = priceX64 >> 96; // Convert from Q192.192 to Q96.96
        price = (getPriceX64(sqrtPriceX96) * 10**18) >> 64; // Convert from Q96.96 to 1e18 fixed point
        price = decimals1>decimals0 ? (price / power) : (price * power);
 
        if (collateralIsOne) {
            require(price > 0, "Price cannot be zero for inverse calculation");
            price = 1e36 / price;
        }
    }

    function getPrice( address option_) public view returns (uint256) {
        OptionPool memory pool = optionPoolList[option_][0];
        return getPrice(getCollateralPrice(pool.collateral), option_);
    }

    function getPrice(uint256 collateralPrice, address option_) public view returns (uint256) {
        IOptionToken option = IOptionToken(option_);
        return optionPrice.getPrice(collateralPrice, option.strike(), option.expirationDate(), option.isPut(), false);
    }

    function getPrices(address collateral) public view returns (CurrentOptionPrice[] memory prices) {
        prices = new CurrentOptionPrice[](allPools.length);
        uint256 collateralPrice = getCollateralPrice(collateral);
        for (uint256 i = 0; i < allPools.length; i++) {
                prices[i] =  CurrentOptionPrice({
                    collateralPrice: collateralPrice,
                    collateral: address(collateral),
                    optionToken: allPools[i].optionToken,
                    price: getPrice(collateralPrice, allPools[i].optionToken)
            });
        }
    }

    function initPool(
        address optionToken,
        address cashToken,
        address collateral,
        address pricePool,
        uint24 fee
    ) public returns (PoolKey memory) {

        IOptionToken option = IOptionToken(optionToken);
        uint256 expiration = option.expirationDate();
        bool optionIsOne = cashToken < optionToken;
        address token0 = optionIsOne ? cashToken : optionToken;
        address token1 = optionIsOne ? optionToken : cashToken;

        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: fee,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(this))
        });
        poolManager.initialize(poolKey, SQRT_PRICE_X96);

        IUniswapV3Pool pool = IUniswapV3Pool(pricePool);
        bool collateralIsOne = pool.token0() == collateral ? pool.token1() == collateral : pool.token0() == collateral;

        OptionPool memory optionPool  = OptionPool({
            collateral: collateral,
            collateralIsOne: collateralIsOne,
            pricePool: pricePool,

            optionIsOne: optionIsOne,
            cashToken: cashToken,
            optionToken: optionToken,
            expiration: expiration,
            strike: option.strike(),

            tickSpacing: TICK_SPACING,
            sqrtPriceX96: SQRT_PRICE_X96,  //todo: verify this
            fee: fee
        });
        allPools.push(optionPool);
        optionPools[toId(poolKey)] = optionPool;
        collateralPools[collateral].push(optionPool);
        optionPoolList[optionToken].push(optionPool);
        return poolKey;
    }

}
