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

import {OptionPrice} from "./OptionPrice.sol";

import {IOptionToken} from "./IOptionToken.sol";


contract OpHook is BaseHook {
    using PoolIdLibrary for PoolKey;

    // NOTE: ---------------------------------------------------------
    // state variables should typically be unique to a pool
    // a single hook contract should be able to service multiple pools
    // ---------------------------------------------------------------

    mapping(PoolId => uint256 count) public beforeSwapCount;
    mapping(PoolId => uint256 count) public afterSwapCount;

    mapping(PoolId => uint256 count) public beforeAddLiquidityCount;
    mapping(PoolId => uint256 count) public beforeRemoveLiquidityCount;

    OptionPrice public immutable optionPrice;

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {
        optionPrice = OptionPrice();
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
        IOptionToken optionToken = IOptionToken(token1);
        require(params.amountSpecified < 0, "amountSpecified must be negative");
        uint256 amount = uint256(-params.amountSpecified);
        if (params.zeroForOne) {
            uint256 price = optionPrice.getPrice(token1, false);
            uint256 token1Amount = (amount * 1e18) / price;
            optionToken.mint(token1Amount);
            BeforeSwapDelta delta = BeforeSwapDeltaLibrary.toBeforeSwapDelta(-amount.toInt128(), token1Amount.toInt128());
        } else {
            uint256 price = optionPrice.getPrice(token1, true);
            uint256 token0Amount = (amount * 1e18) / price;
            optionToken.redeem(amount);
            BeforeSwapDelta delta = BeforeSwapDeltaLibrary.toBeforeSwapDelta(token0Amount.toInt128(), -amount.toInt128());
        }
        return (BaseHook.beforeSwap.selector, delta, 0);
    }

}
