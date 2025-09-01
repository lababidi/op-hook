// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/OpHook.sol";
import "../contracts/IOptionToken.sol";
import "../contracts/MockOptionToken.sol";
import {HookMiner} from "lib/uniswap-hooks/lib/v4-periphery/src/utils/HookMiner.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IWETH9} from "lib/v4-periphery/src/interfaces/external/IWETH9.sol";


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

import {OptionPrice, IUniswapV3Pool} from "../contracts/OptionPrice.sol";

import {IOptionToken} from "../contracts/IOptionToken.sol";
import {IPermit2} from "../contracts/IPermit2.sol";

import {IHooks} from "v4-core/src/interfaces/IHooks.sol";

contract UniOpHookTest is Test {
    // using EasyPosm for IPositionManager;
    // using StateLibrary for IPoolManager;

    // PointsHook hook;
    // PointsToken pointsToken;
    // PoolId poolId;

    uint256 tokenId;
    int24 tickLower;
    int24 tickUpper;

    function setUp() public {
        // creates the pool manager, utility routers, and test tokens
        // deployFreshManagerAndRouters();
        // deployMintAndApprove2Currencies();

        // deployAndApprovePosm(manager);

        // // Deploy the hook to an address with the correct flags
        // address flags = address(
        //     uint160(Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_ADD_LIQUIDITY_FLAG) ^
        //         (0x4444 << 144) // Namespace the hook to avoid collisions
        // );
        // bytes memory constructorArgs = abi.encode(manager); //Add all the necessary constructor arguments from the hook
        // deployCodeTo("PointsHook.sol:PointsHook", constructorArgs, flags);
        // hook = PointsHook(flags);
        // pointsToken = hook.pointsToken();

        // // Create the pool
        // key = PoolKey(
        //     Currency.wrap(address(0)),
        //     currency1,
        //     3000,
        //     60,
        //     IHooks(hook)
        // );
        // poolId = key.toId();
        // manager.initialize(key, SQRT_PRICE_1_1);

        // // Provide full-range liquidity to the pool
        // tickLower = TickMath.minUsableTick(key.tickSpacing);
        // tickUpper = TickMath.maxUsableTick(key.tickSpacing);

        // deal(address(this), 200 ether);

        // (uint256 amount0, uint256 amount1) = LiquidityAmounts
        //     .getAmountsForLiquidity(
        //         SQRT_PRICE_1_1,
        //         TickMath.getSqrtPriceAtTick(tickLower),
        //         TickMath.getSqrtPriceAtTick(tickUpper),
        //         uint128(100e18)
        //     );

        // (tokenId, ) = posm.mint(
        //     key,
        //     tickLower,
        //     tickUpper,
        //     100e18,
        //     amount0 + 1,
        //     amount1 + 1,
        //     address(this),
        //     block.timestamp,
        //     hook.getHookData(address(this))
        // );
    }

    function test_PointsHook_Swap() public {
        // [code here]
    }
}