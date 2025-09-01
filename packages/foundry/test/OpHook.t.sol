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
import {SwapParams, PoolKey} from "v4-core/src/types/PoolOperation.sol";
import {PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BeforeSwapDelta, toBeforeSwapDelta} from "v4-core/src/types/BeforeSwapDelta.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";

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
import {ConstantsMainnet} from "../contracts/ConstantsMainnet.sol";
import {SafeCallback} from "./SafeCallback.sol";

contract SwapCallback is SafeCallback {
    OpHook public opHook;
    PoolKey public poolKey;
    constructor(IPoolManager _poolManager, OpHook _opHook, PoolKey memory _poolKey) SafeCallback(_poolManager) {
        poolKey = _poolKey;
        opHook = _opHook;
    }
    function _unlockCallback(bytes calldata data) internal override returns (bytes memory) {
        // (...) = abi.decode(data, (...));

        SwapParams memory params = SwapParams({
            zeroForOne: false,
            amountSpecified: -1e6,
            sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE-1    
        });
        bytes memory d = bytes("");
        IERC20 usdc = IERC20(Currency.unwrap(poolKey.currency1));
        IERC20 option = IERC20(Currency.unwrap(poolKey.currency0));
        BalanceDelta delta = poolManager.swap(poolKey, params, d);
        poolManager.sync(poolKey.currency1);
        usdc.transfer(address(poolManager), 1e6);
        poolManager.take(poolKey.currency0, address(this), uint128(delta.amount0()));
        poolManager.settle();
        console.log("delta0", delta.amount0());
        console.log("delta1", delta.amount1());
        console.log("option balance", option.balanceOf(address(poolManager)));
        console.log("option balance", option.balanceOf(address(this)));
        console.log("usdc balance", usdc.balanceOf(address(poolManager)));
        console.log("usdc balance", usdc.balanceOf(address(this)));
        

        // poolManager.sync();
        return data;
    }
    function swap() public {
        poolManager.unlock(bytes(""));
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
    
    function setUp() public {

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
        usdc.approve(address(opHook), 1000e6);
        usdc.approve(ConstantsMainnet.POOLMANAGER, 1000e6);
        usdc.approve(ConstantsMainnet.PERMIT2, 1000e6);
    }

    // function testSwap() public {
    //     opHook.swap(address(option1), 1000e6, address(this));
    // }

    function testSwapCallback() public {
        IPoolManager poolManager = IPoolManager(ConstantsMainnet.POOLMANAGER);  
        SwapCallback swapCallback = new SwapCallback(poolManager, opHook, poolKey1);
        address swapcb = address(swapCallback);
        deal(ConstantsMainnet.USDC, swapcb, 1000e6);
        swapCallback.swap();
        console.log("option1 balance", option1.balanceOf(swapcb));
        console.log("option1 balance", option1.balanceOf(address(opHook)));
        console.log("option2 balance", option2.balanceOf(address(this)));
        console.log("WETH balance", weth.balanceOf(address(this)));
        console.log("WETH balance", weth.balanceOf(address(opHook)));
        console.log("USDC balance", usdc.balanceOf(address(this)));

        console.log("USDC balance", usdc.balanceOf(address(opHook)));
        console.log("USDC balance", usdc.balanceOf(swapcb));
        console.log("ophookaddress", address(opHook));
    }

    // function testGetUnderlyingPrice() public view {
    //     uint256 price = opHook.getCollateralPrice();
    //     console.log("price", price);
    // }
    
    // function testGetOptionPrice() public view {
    //     // Test getOptionPrice function with mock option token
    //     // Note: This will likely fail because OptionPrice needs proper setup,
    //     // but let's test the interface
    //     CurrentOptionPrice memory price = opHook.getOptionPrice(address(option1));
    //     // If it doesn't revert, verify the structure
    //     assertEq(price.collateral, address(weth), "Underlying should match");
    //     assertEq(price.optionToken, address(option1), "Option token should match");
    //     console.log(option1.strike());
    //     console.log(option1.expirationDate());
    //     console.log(option1.STRIKE_DECIMALS());
    //     console.log(option1.isPut());
    //     console.log(address(option1));
    //     console.log(address(option1.collateral()));
    //     console.log(address(option1.consideration()));
    //     console.log(option1.initialized());
    //     console.log(price.collateral);
        

    //     console.log("price", price.price);
    //     // Price could be any value, just check it's returned
    //     assertTrue(price.price >= 0, "Price should be non-negative");

    // }

    // function testUserAccountWithEthWethAndSwap() public {
    //     // Set up user account
    //     address user = address(0x123456789);
    //     uint256 initialEthAmount = 10 ether;
        
    //     // Deal ETH to user account
    //     vm.deal(user, initialEthAmount);
    //     assertEq(user.balance, initialEthAmount, "User should have initial ETH");
        
    //     // Wrap ETH to WETH
    //     uint256 wrapAmount = 5 ether;
    //     vm.prank(user);
    //     weth.deposit{value: wrapAmount}();
        
    //     // Verify WETH balance
    //     assertEq(weth.balanceOf(user), wrapAmount, "User should have WETH");
    //     assertEq(user.balance, initialEthAmount - wrapAmount, "User ETH should be reduced");
        
    //     // For swapping to USDC, we'll use a simple approach with deal
    //     // In a real test, you'd integrate with Uniswap V3 or another DEX
    //     // For now, we'll simulate receiving USDC after "swapping"
    //     uint256 swapAmount = 2 ether; // 2 WETH to swap
    //     uint256 usdcReceived = 4000 * 1e6; // Assume ~$2000 per ETH, USDC has 6 decimals
        
    //     // Approve WETH spending (would be for actual DEX)
    //     vm.prank(user);
    //     weth.approve(address(this), swapAmount);
        
    //     // Simulate the swap by dealing USDC and reducing WETH
    //     vm.startPrank(user);
    //     weth.transfer(address(0xdead), swapAmount); // Burn WETH to simulate swap
    //     vm.stopPrank();
        
    //     // Deal USDC to simulate swap result
    //     deal(MAINNET_USDC, user, usdcReceived);
        
    //     // Verify final balances
    //     assertEq(weth.balanceOf(user), wrapAmount - swapAmount, "WETH balance should be reduced");
    //     assertEq(IERC20(MAINNET_USDC).balanceOf(user), usdcReceived, "User should have USDC");
        
    //     console.log("User account setup complete:");
    //     console.log("- ETH balance:", user.balance);
    //     console.log("- WETH balance:", weth.balanceOf(user));
    //     console.log("- USDC balance:", IERC20(MAINNET_USDC).balanceOf(user));
    // }

}
