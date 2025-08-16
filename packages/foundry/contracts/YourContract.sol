// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "@openzeppelin/uniswap-hooks/src/base/BaseHook.sol";

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager, SwapParams, ModifyLiquidityParams} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IOptionPriceOracle {
    function getPrice(address token) external view returns (uint256);
}

interface IOptionFactory {
    function mint(uint256 amount) external;
}

interface IOptionToken {
    function getOptionToken(address token0, address token1) external view returns (address);
    IERC20 public collateral;
}

contract Counter is BaseHook {
    using PoolIdLibrary for PoolKey;

    IOptionPriceOracle public immutable priceOracle;
    IOptionFactory public immutable optionFactory;
    // NOTE: ---------------------------------------------------------
    // state variables should typically be unique to a pool
    // a single hook contract should be able to service multiple pools
    // ---------------------------------------------------------------

    mapping(PoolId => uint256 count) public beforeSwapCount;
    mapping(PoolId => uint256 count) public afterSwapCount;

    mapping(PoolId => uint256 count) public beforeAddLiquidityCount;
    mapping(PoolId => uint256 count) public beforeRemoveLiquidityCount;

    constructor(IPoolManager _poolManager, address _priceOracle, address _optionFactory) BaseHook(_poolManager) {
        priceOracle = IOptionPriceOracle(_priceOracle);
        optionFactory = IOptionFactory(_optionFactory);
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory permissions) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // -----------------------------------------------
    // NOTE: see IHooks.sol for function documentation
    // -----------------------------------------------

    function _beforeSwap(address, PoolKey calldata key, SwapParams calldata params, bytes calldata)
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);
        if (params.zeroForOne) {
            IOptionToken optionToken = IOptionToken(token1);
            require(address(optionToken.collateral()) == token1, "Collateral mismatch");
            // token0->token1
            // get a price for the option token token0->token1 from the oracle
            uint256 price = priceOracle.getPrice(token1);
            // Calculate how much of token1 is available to the user based on the amount of token0 and the price (18 decimals)
            // Assume params.amountSpecified is the amount of token0 the user wants to swap
            // token1Amount = (token0Amount * 1e18) / price

            //todo: need to propertly create the int128 values

            uint256 token0Amount = uint256(params.amountSpecified);
            uint256 token1Amount = (token0Amount * 1e18) / price;
            // mint the option token
            optionFactory.mint(token1Amount);
            // return the delta
            return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.toBeforeSwapDelta(toInt128(token0Amount), toInt128(token1Amount)), 0);

        } else {
            // token1->token0
            // get a price for the option token token1->token0 from the oracle
            IOptionToken optionToken = IOptionToken(token1);
            require(address(optionToken.collateral()) == token1, "Collateral mismatch");
            // get a price for the option token token1->token0 from the oracle
            uint256 price = priceOracle.getInversePrice(token1);
            // Calculate how much of token1 is available to the user based on the amount of token0 and the price (18 decimals)
            // Assume params.amountSpecified is the amount of token1 the user wants to swap
            // token0Amount = (token1Amount * 1e18) / price
            uint256 token1Amount = uint256(params.amountSpecified);
            uint256 token0Amount = (token1Amount * 1e18) / price;
            // mint the option token
            optionFactory.redeem(token1Amount);
            // return the delta
            return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.toBeforeSwapDelta(token0Amount, token1Amount.toInt128()), 0);

        }
        // determine which direction: true = token0->token1, false = token1->token0
        beforeSwapCount[key.toId()]++;
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

}
