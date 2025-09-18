// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";
import {OpHook} from "../contracts/OpHook.sol";
import {ScaffoldETHDeploy} from "./DeployHelpers.s.sol";


import {HookMiner} from "lib/uniswap-hooks/lib/v4-periphery/src/utils/HookMiner.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IWETH9} from "@uniswap/v4-periphery/src/interfaces/external/IWETH9.sol";
import { UniversalRouter } from "@uniswap/universal-router/contracts/UniversalRouter.sol";
import { IV4Router } from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";
import { Actions } from "@uniswap/v4-periphery/src/libraries/Actions.sol";
import { Commands } from "@uniswap/universal-router/contracts/libraries/Commands.sol";

import {CurrencySettler} from "@uniswap/v4-core/test/utils/CurrencySettler.sol";


import {BaseHook} from "@openzeppelin/uniswap-hooks/src/base/BaseHook.sol";

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {SwapParams, PoolKey} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BeforeSwapDelta, toBeforeSwapDelta} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";

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

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {ConstantsUnichain} from "../contracts/ConstantsUnichain.sol";
import {NonzeroDeltaCount} from "lib/uniswap-hooks/lib/v4-core/src/libraries/NonzeroDeltaCount.sol";



/// @notice Mines the address and deploys the PointsHook.sol Hook contract
contract DeployOp is Script, ScaffoldETHDeploy {
    function setUp() public {}

    function run() public ScaffoldEthDeployerRunner{


        address deployer = ConstantsUnichain.CREATE2_DEPLOYER;
        // Deploy OpHook using HookMiner to get correct address
        uint160 flags = Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_DONATE_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG;
        bytes memory constructorArgs = abi.encode(
            IPoolManager(ConstantsUnichain.POOLMANAGER),
            ConstantsUnichain.PERMIT2,
            ConstantsUnichain.WETH,
            ConstantsUnichain.USDC,
            "WethOptionPoolVault",
            "ETHCC",
            ConstantsUnichain.WETH_UNI_POOL
        );

        (address hookAddress, bytes32 salt) = HookMiner.find(
            deployer,
            flags,
            type(OpHook).creationCode,
            constructorArgs
        );

        console.log("Address", hookAddress);

        OpHook opHook = new OpHook{salt: salt}(
            IPoolManager(ConstantsUnichain.POOLMANAGER),
            ConstantsUnichain.PERMIT2,
            ConstantsUnichain.WETH,
            ConstantsUnichain.USDC,
            "WethOptionPoolVault",
            "ETHCC",
            ConstantsUnichain.WETH_UNI_POOL
        );


        console.log("Address", hookAddress);
        console.log("Address", address(opHook));

        require(address(opHook) == hookAddress, " hook address mismatch");



    }
}