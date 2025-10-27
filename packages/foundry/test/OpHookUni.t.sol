// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {OpHook, CurrentOptionPrice} from "../contracts/OpHook.sol";
import {IOptionToken} from "../contracts/IOptionToken.sol";
import {MockOptionToken} from "../contracts/MockOptionToken.sol";
import {HookMiner} from "@openzeppelin/uniswap-hooks/lib/v4-periphery/src/utils/HookMiner.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH9} from "@uniswap/v4-periphery/src/interfaces/external/IWETH9.sol";
import { UniversalRouter } from "@uniswap/universal-router/contracts/UniversalRouter.sol";
import { IV4Router } from "@uniswap/v4-periphery/src/interfaces/IV4Router.sol";
import { Actions } from "@uniswap/v4-periphery/src/libraries/Actions.sol";

import {CurrencySettler} from "@uniswap/v4-core/test/utils/CurrencySettler.sol";


import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {SwapParams, PoolKey} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";


import {IOptionToken} from "../contracts/IOptionToken.sol";
import {IPermit2} from "../contracts/IPermit2.sol";

import {SafeCallback} from "./SafeCallback.sol";
import {NonzeroDeltaCount} from "lib/uniswap-hooks/lib/v4-core/src/libraries/NonzeroDeltaCount.sol";
import {ConstantsUnichain} from "../contracts/ConstantsUnichain.sol";

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
            zeroForOne: true,
            amountSpecified: -amountIn,
            sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE-1    
        });
        bytes memory d = bytes("");
        IERC20 usdc = IERC20(Currency.unwrap(poolKey.currency0));
        IERC20 option = IERC20(Currency.unwrap(poolKey.currency1));
        uint256 initBal = usdc.balanceOf(address(poolManager));
        poolKey.currency0.settle(poolManager, sender, 1e6, false);
        console.log("delta", NonzeroDeltaCount.read());

        BalanceDelta delta = poolManager.swap(poolKey, params, d);
        console.log("delta0", delta.amount0());
        console.log("delta1", delta.amount1());
        console.log("delta", NonzeroDeltaCount.read());
        poolKey.currency1.take(poolManager, address(this), uint128(delta.amount1()), false);
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
    address public weth_;
    address public usdc_;
    address public permit2_;
    address public poolManager_;
    address public option1_;
    address public option2_;
    address public option3_;
    address public option4_;
    IOptionToken public option1;
    IOptionToken public option2;
    PoolKey public poolKey1;
    PoolKey public poolKey2;
    IPoolManager poolManager;

    IPermit2 permit2;
    string rpc = "https://unichain.drpc.org";
    uint mainnetFork;
    
    function setUp() public {
        weth_ = ConstantsUnichain.WETH;
        usdc_ = ConstantsUnichain.USDC;
        permit2_ = ConstantsUnichain.PERMIT2;
        poolManager_ = ConstantsUnichain.POOLMANAGER;

        mainnetFork = vm.createSelectFork(rpc, 27503100);
        poolManager = IPoolManager(poolManager_);

        deal(address(this), 10000e20 ether);
        deal(usdc_, address(this), 1000e6);
        // Deploy mock tokens
        weth = IWETH9(weth_);
        usdc = IERC20(usdc_);
        permit2 = IPermit2(permit2_);
        option1_ = 0xCfFDd882327d7036bb3cD4Fee21Ae4e8019f957d;
        option2_ = 0xb52773b8E210DA987F2328D84d31445102dC0158;
        option3_ = 0xb3f77B5Eb9e898D970c46B1aeF439b0a3e5fCbc9;
        option1 = MockOptionToken(option1_);
        option2 = MockOptionToken(option2_);
        // option1 = new MockOptionToken("WETH-4000", "MOPT4", ConstantsUnichain.WETH, ConstantsUnichain.USDC, block.timestamp + 30 days, 4000 * 1e18, false);
        // option2 = new MockOptionToken("WETH-5000", "MOPT5", ConstantsUnichain.WETH, ConstantsUnichain.USDC, block.timestamp + 30 days, 5000 * 1e18, false);
        // Deploy OpHook using HookMiner to get correct address
        uint160 flags = Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_DONATE_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG;
        bytes memory constructorArgs = abi.encode(
            IPoolManager(poolManager_),
            permit2_,
            weth_,
            usdc_,
            "WethOptionPoolVault",
            "ETHCC",
            ConstantsUnichain.WETH_UNI_POOL
        );

        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            type(OpHook).creationCode,
            constructorArgs
        );

        opHook = new OpHook{salt: salt}(
            IPoolManager(poolManager_),
            permit2_,
            weth_,
            usdc_,
            "WethOptionPoolVault",
            "ETHCC",
            ConstantsUnichain.WETH_UNI_POOL
        );
        // address opHook_ = 0x8C30f089Ee553a74B42cC884777Cb74E595688a8;
        // opHook = OpHook(opHook_);
        address opHook_ = address(opHook);


        console.log("Address", hookAddress);
        console.log("Address", opHook_);

        poolKey1 = opHook.initPool(option1_, 0);
        poolKey2 = opHook.initPool(option2_, 0);
        console.log("Pool1", Currency.unwrap(poolKey1.currency0));
        console.log("Pool1", Currency.unwrap(poolKey1.currency1));
        console.log("Pool2", Currency.unwrap(poolKey2.currency0));
        console.log("Pool2", Currency.unwrap(poolKey2.currency1));

        deal(weth_, opHook_, 1000e18);
        deal(usdc_, opHook_, 1000e18);
        deal(usdc_, poolManager_, 1000e18);
        console.log("USDC balance POOLMANAGER", usdc.balanceOf(poolManager_));
        usdc.approve(opHook_, 1000e6);
        usdc.approve(poolManager_, 1000e6);
        usdc.approve(permit2_, 1000e6);
        usdc.approve(poolManager_, 1000e6);
        usdc.approve(permit2_, 1000e6);
        usdc.approve(poolManager_, 1000e6);
        vm.prank(poolManager_);
        usdc.approve(permit2_, 1000e6);

        
        permit2.approve(usdc_, poolManager_, type(uint160).max, uint48(block.timestamp + 1 days));

        opHook = OpHook(0x8C30f089Ee553a74B42cC884777Cb74E595688a8);
        permit2.approve(usdc_, opHook_, type(uint160).max, uint48(block.timestamp + 1 days));

        permit2.approve(usdc_, poolManager_, type(uint160).max, uint48(block.timestamp + 1 days));

    }

    function testPrices() public  {
        console.log("USDC balance POOLMANAGER", usdc.balanceOf(poolManager_));
        opHook.initPool(option3_, 0);
        CurrentOptionPrice[] memory prices = opHook.getPrices();
        console.log("price1", prices[0].price / 1e18);
        console.log("price2", prices[1].price / 1e18);  
        // console.log("price3", prices[2].price / 1e18);    
    }


    function testPrice() public  {
        opHook.initPool(option3_, 0);
        IOptionToken option = IOptionToken(option3_);
        console.log("strike", option.strike());
        console.log("underlying", address(option.collateral()));
        console.log("expiration", option.expirationDate());
        console.log("isPut", option.isPut());
        uint256 price = opHook.getPrice(option3_);
        CurrentOptionPrice[] memory prices = opHook.getPrices();
        console.log("price1", prices[0].price / 1e18);
        console.log("price2", prices[1].price / 1e18);
        // console.log("price3", prices[2].price / 1e18);
        console.log("price", price / 1e18);
    }

    function testSwapCallback() public {
        SwapCallback swapCallback = new SwapCallback(poolManager, opHook, poolKey1);
        address swapcb = address(swapCallback);
        deal(address(usdc), swapcb, 1000e18);
        deal(address(usdc), address(this), 1000e18);
        usdc.approve(ConstantsUnichain.PERMIT2, 1000e6);
        usdc.approve(swapcb, 1000e6);
        usdc.approve(poolManager_, 1000e6);
        swapCallback.swap(address(this));

    }

    function testRouterSwap() public {
        UniversalRouter router = UniversalRouter(payable(ConstantsUnichain.UNIVERSALROUTER));
        deal(ConstantsUnichain.USDC, address(this), 1000e6);
        usdc.approve(address(router), 1000e6);        
        permit2.approve(address(usdc), address(router), type(uint160).max, uint48(block.timestamp + 1 days));

        // currency0 = option, currency1 = usdc

        uint256 v4Swap = 0x10;

        bytes memory commands = abi.encodePacked(uint8(v4Swap));
        bytes memory actions = abi.encodePacked(
            uint8(Actions.SWAP_EXACT_IN_SINGLE),
            uint8(Actions.SETTLE_ALL),
            uint8(Actions.TAKE_ALL)
        );

        bytes[] memory params = new bytes[](3);

        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: poolKey1,
                zeroForOne: true,
                amountIn: 1e6,
                amountOutMinimum: 0,
                hookData: bytes("")
            })
        );
        params[1] = abi.encode(poolKey1.currency0, type(uint256).max);
        params[2] = abi.encode(poolKey1.currency1, 0);

        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(actions, params);

        router.execute(commands, inputs, block.timestamp + 20);

        console.log("option1 balance", option1.balanceOf(address(this)));
        console.log("option1 balance", option1.balanceOf(address(opHook)));
        console.log("WETH balance", weth.balanceOf(address(opHook)));
        console.log("USDC balance", usdc.balanceOf(address(this)));

        console.log("USDC balance", usdc.balanceOf(address(opHook)));
        console.log("USDC balance", usdc.balanceOf(address(this)));
        console.log("USDC balance", usdc.balanceOf(poolManager_));
    }



}
