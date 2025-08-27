// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../contracts/OpHook.sol";
import {HookMiner} from "lib/uniswap-hooks/lib/v4-periphery/src/utils/HookMiner.sol";

contract OpHookTest is Test {
    OpHook public opHook;

    function testOpHookCompilation() public  {
        // Basic test to ensure the contract compiles successfully
        // The counter contract is a Uniswap v4 hook that tracks swap and liquidity events
        IPoolManager poolManager = IPoolManager(address(0x1234567890123456789012345678901234567890));
        address permit2 = address(0x1234567890123456789012345678901234567890);
        IERC20 weth = IERC20(address(0x1234567890123456789012345678901234567890));

        uint160 flags = Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_DONATE_FLAG;
        bytes memory constructorArgs = abi.encode(IPoolManager(address(poolManager)), permit2, IERC20(weth), "WethOptionPoolVault", "ETHCC");

        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            type(OpHook).creationCode,
            constructorArgs
        );
        console.log("hookAddress", hookAddress);
        console.log("salt", uint256(salt));

        OpHook hook = new OpHook{salt: salt}(IPoolManager(address(poolManager)), permit2, IERC20(weth), "WethOptionPoolVault", "ETHCC");
        assert(true);
    }
}
