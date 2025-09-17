// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/OpHook.sol";
import "../contracts/IOptionToken.sol";
import "../contracts/MockOptionToken.sol";
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
import {ConstantsMainnet} from "../contracts/ConstantsMainnet.sol";
import {SafeCallback} from "./SafeCallback.sol";
import {NonzeroDeltaCount} from "lib/uniswap-hooks/lib/v4-core/src/libraries/NonzeroDeltaCount.sol";


contract SwapCallback is SafeCallback {
    OpHook public opHook;
    PoolKey public poolKey;
    using CurrencySettler for Currency;

    constructor(IPoolManager _poolManager, OpHook _opHook, PoolKey memory _poolKey) SafeCallback(_poolManager) {
        poolKey = _poolKey;
        opHook = _opHook;
    }
    function _unlockCallback(bytes calldata data) internal override returns (bytes memory) {
        (address sender) = abi.decode(data, (address));

        int256 amountIn = 1e6;
        SwapParams memory params = SwapParams({
            zeroForOne: false,
            amountSpecified: -amountIn,
            sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE-1    
        });
        bytes memory d = bytes("");
        IERC20 usdc = IERC20(Currency.unwrap(poolKey.currency1));
        IERC20 option = IERC20(Currency.unwrap(poolKey.currency0));
        uint256 initBal = usdc.balanceOf(address(poolManager));
        poolKey.currency1.settle(poolManager, sender, 1e6, false);
        console.log("delta", NonzeroDeltaCount.read());

        BalanceDelta delta = poolManager.swap(poolKey, params, d);
        console.log("delta0", delta.amount0());
        console.log("delta1", delta.amount1());
        console.log("delta", NonzeroDeltaCount.read());
        // usdc.transfer(address(poolManager), 1e6);
        poolKey.currency0.take(poolManager, address(this), uint128(delta.amount0()), false);
        // poolManager.take(poolKey.currency0, address(this), uint128(delta.amount0()));
        console.log("delta", NonzeroDeltaCount.read());
        // poolManager.sync(poolKey.currency1);
        // console.log("delta", NonzeroDeltaCount.read());
        // poolManager.settle();
        console.log("delta", NonzeroDeltaCount.read());
        console.log("option balance", option.balanceOf(address(poolManager)));
        console.log("option balance", option.balanceOf(address(this)));
        console.log("usdc balance", int256(usdc.balanceOf(address(poolManager))) - int256(initBal));
        console.log("usdc balance", usdc.balanceOf(address(sender)));
        console.log("option balance", option.balanceOf(address(sender)));
        

        // poolManager.sync();
        return data;
    }
    function swap(address sender) public {
        poolManager.unlock(abi.encode(sender));
    }
}


contract OpHookTest is Test {
    // Real Mainnet addresses for testing

    OpHook public opHook;
    IERC20 public usdc;
    IWETH9 public weth;
    MockOptionToken public option1;
    MockOptionToken public option2;
    address optionAddress;
    PoolKey public poolKey1;
    PoolKey public poolKey2;
    IPoolManager poolManager;
    string MAINNET_RPC_URL = "https://reth-ethereum.ithaca.xyz/rpc";
    uint mainnetFork;
    
    function setUp() public {

        mainnetFork = vm.createSelectFork(MAINNET_RPC_URL, 23359458);
        poolManager = IPoolManager(ConstantsMainnet.POOLMANAGER);

        deal(address(this), 10000e20 ether);
        deal(ConstantsMainnet.USDC, address(this), 1000e6);
        // Deploy mock tokens
        weth = IWETH9(ConstantsMainnet.WETH);
        usdc = IERC20(ConstantsMainnet.USDC);
        option1 = new MockOptionToken("WETH-4000", "MOPT4", ConstantsMainnet.WETH, ConstantsMainnet.USDC, block.timestamp + 30 days, 4000 * 1e18, false);
        option2 = new MockOptionToken("WETH-5000", "MOPT5", ConstantsMainnet.WETH, ConstantsMainnet.USDC, block.timestamp + 30 days, 5000 * 1e18, false);
        // Deploy OpHook using HookMiner to get correct address
        uint160 flags = Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_DONATE_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG;
        bytes memory constructorArgs = abi.encode(
            IPoolManager(ConstantsMainnet.POOLMANAGER),
            ConstantsMainnet.PERMIT2,
            ConstantsMainnet.WETH,
            ConstantsMainnet.USDC,
            "WethOptionPoolVault",
            "ETHCC",
            ConstantsMainnet.WETH_UNI_POOL
        );

        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            type(OpHook).creationCode,
            constructorArgs
        );

        opHook = new OpHook{salt: salt}(
            IPoolManager(ConstantsMainnet.POOLMANAGER),
            ConstantsMainnet.PERMIT2,
            ConstantsMainnet.WETH,
            ConstantsMainnet.USDC,
            "WethOptionPoolVault",
            "ETHCC",
            ConstantsMainnet.WETH_UNI_POOL
        );


        console.log("Address", hookAddress);
        console.log("Address", address(opHook));

        poolKey1 = opHook.initPool(address(option1), 0);
        poolKey2 = opHook.initPool(address(option2), 0);


        deal(address(weth), address(opHook), 1000e18);
        deal(address(usdc), address(opHook), 1000e18);
        usdc.approve(address(opHook), 1000e6);
        usdc.approve(ConstantsMainnet.POOLMANAGER, 1000e6);
        usdc.approve(ConstantsMainnet.PERMIT2, 1000e6);
    }

    function testPrices() public  {
        opHook.initPool(0xd549Cb6Fd983a5E2b6252f1C41d5dA8Fd04B3339, 0);
        CurrentOptionPrice[] memory prices = opHook.getPrices();
        console.log("price1", prices[0].price / 1e18);
        console.log("price2", prices[1].price / 1e18);  
        console.log("price2", prices[2].price / 1e18);    
    }


    function testPrice() public  {
        address option_ = 0xd549Cb6Fd983a5E2b6252f1C41d5dA8Fd04B3339;
        opHook.initPool(option_, 0);
        IOptionToken option = IOptionToken(option_);
        console.log("strike", option.strike());
        console.log("underlying", address(option.collateral()));
        console.log("expiration", option.expirationDate());
        console.log("isPut", option.isPut());
        // CurrentOptionPrice memory price = opHook.getPrice();
        // CurrentOptionPrice[] memory prices = opHook.getPrices();
        // console.log("price1", prices[0].price / 1e18);
        // console.log("price2", prices[1].price / 1e18);  
        // console.log("price2", prices[2].price / 1e18);    
    }

    function testSwapCallback() public {
        SwapCallback swapCallback = new SwapCallback(poolManager, opHook, poolKey1);
        address swapcb = address(swapCallback);
        deal(address(usdc), swapcb, 1000e18);
        deal(address(usdc), address(this), 1000e18);
        usdc.approve(ConstantsMainnet.PERMIT2, 1000e6);
        usdc.approve(swapcb, 1000e6);
        usdc.approve(ConstantsMainnet.POOLMANAGER, 1000e6);
        swapCallback.swap(address(this));

    }

    function testRouterSwap() public {
        UniversalRouter router = UniversalRouter(payable(ConstantsMainnet.UNIVERSALROUTER));
        deal(ConstantsMainnet.USDC, address(this), 1000e6);
        usdc.approve(address(router), 1000e6);
        usdc.approve(address(poolManager), 1000e6);
        usdc.approve(ConstantsMainnet.PERMIT2, 1000e6);
        
        IPermit2 permit2 = IPermit2(ConstantsMainnet.PERMIT2);
        permit2.approve(address(usdc), address(router), type(uint160).max, uint48(block.timestamp + 1 days));
        permit2.approve(address(usdc), address(poolManager), type(uint160).max, uint48(block.timestamp + 1 days));

        // currency0 = option, currency1 = usdc

        uint256 V4_SWAP = 0x10;

        bytes memory commands = abi.encodePacked(uint8(V4_SWAP));
        bytes memory actions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_IN_SINGLE),
            uint8(Actions.SETTLE_ALL),
            uint8(Actions.TAKE_ALL)
        );

        bytes[] memory params = new bytes[](3);

        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: poolKey1,
                zeroForOne: false,
                amountIn: 1e6,
                amountOutMinimum: 0,
                hookData: bytes("")
            })
        );
        params[1] = abi.encode(poolKey1.currency1, type(uint256).max);
        params[2] = abi.encode(poolKey1.currency0, 0);

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(actions, params);

        router.execute(commands, inputs, block.timestamp + 20);

        console.log("option1 balance", option1.balanceOf(address(this)));
        console.log("option1 balance", option1.balanceOf(address(opHook)));
        console.log("WETH balance", weth.balanceOf(address(opHook)));
        console.log("USDC balance", usdc.balanceOf(address(this)));

        console.log("USDC balance", usdc.balanceOf(address(opHook)));
        console.log("USDC balance", usdc.balanceOf(address(this)));
        console.log("USDC balance", usdc.balanceOf(address(poolManager)));
    }

}
