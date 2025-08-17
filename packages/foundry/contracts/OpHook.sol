// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {BaseHook} from "@openzeppelin/uniswap-hooks/src/base/BaseHook.sol";

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager, SwapParams, ModifyLiquidityParams} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary, toBeforeSwapDelta} from "v4-core/src/types/BeforeSwapDelta.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {OptionPrice} from "./OptionPrice.sol";

import {IOptionToken} from "./IOptionToken.sol";
import {IPermit2} from "./IPermit2.sol";
import {ISignatureTransfer} from "./ISignatureTransfer.sol";


contract OpHook is BaseHook {
    using PoolIdLibrary for PoolKey;

    OptionPrice public  optionPrice;

    IPermit2 public immutable PERMIT2;

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {
        optionPrice = new OptionPrice();
        PERMIT2 = IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
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

    function _beforeSwap(address, PoolKey calldata key, SwapParams calldata params, bytes calldata)
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        address token1 = Currency.unwrap(key.currency1);
        IOptionToken optionToken = IOptionToken(token1);
        require(params.amountSpecified < 0, "amountSpecified must be negative");
        uint256 amount = uint256(-params.amountSpecified);
        int128 amount_ = int128(int256(amount));
        if (params.zeroForOne) {
            uint256 price = optionPrice.getPrice(token1, false);
            uint256 token1Amount = (amount * price) / 1e18;
            int128 token1Amount_ = int128(int256(token1Amount));
            require(token1Amount <= optionToken.balanceOf(address(this)), "Insufficient optionToken balance");

            optionToken.mint(token1Amount);
            BeforeSwapDelta delta = toBeforeSwapDelta(-amount_, token1Amount_);
            poolManager.mint(address(this), key.currency0.toId(), amount);
            poolManager.burn(address(this), key.currency1.toId(), token1Amount);
            return (BaseHook.beforeSwap.selector, delta, 0);
        } else {
            uint256 price = optionPrice.getPrice(token1, true);
            uint256 token0Amount = (amount * price) / 1e18;
            int128 token0Amount_ = int128(int256(token0Amount));
            optionToken.redeem(amount);
            BeforeSwapDelta delta = toBeforeSwapDelta(token0Amount_, -amount_);
            poolManager.mint(address(this), key.currency1.toId(), amount);
            poolManager.burn(address(this), key.currency0.toId(), token0Amount);
            poolManager.settle();
            return (BaseHook.beforeSwap.selector, delta, 0);
        }
    }

    function addLiquidity(
        IPermit2.PermitTransferFrom calldata permit, 
        IPermit2.SignatureTransferDetails calldata transferDetails, 
        address owner, 
        bytes calldata signature
        ) public {
            // NOTE: this is a hack to add liquidity to the pool using the underlying asset
            // needs to be converted to something like a uniswap NFT token
        
        PERMIT2.permitTransferFrom(permit, transferDetails, owner, signature);

    }

    function removeLiquidity(
        IPermit2.PermitTransferFrom calldata permit, 
        IPermit2.SignatureTransferDetails calldata transferDetails, 
        address owner, 
        bytes calldata signature
        ) public {
        
        PERMIT2.permitTransferFrom(permit, transferDetails, owner, signature);
    }

}
