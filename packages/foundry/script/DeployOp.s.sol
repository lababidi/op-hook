// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";
import {OpHook} from "../contracts/OpHook.sol";
import {ConstantsMainnet} from "../contracts/ConstantsMainnet.sol";


/// @notice Mines the address and deploys the PointsHook.sol Hook contract
contract PointsHookScript is Script {
    function setUp() public {}

    function run() public {

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
            ConstantsMainnet.CREATE2_DEPLOYER,
            flags,
            type(OpHook).creationCode,
            constructorArgs
        );

        // Deploy the hook using CREATE2
        // forge script script/DeployOp.s.sol --broadcast --private-key [KEY]
        vm.createSelectFork("http://localhost:8545");
        vm.broadcast();
        OpHook opHook = new OpHook{salt: salt}(
            IPoolManager(ConstantsMainnet.POOLMANAGER),
            ConstantsMainnet.PERMIT2,
            ConstantsMainnet.WETH,
            ConstantsMainnet.USDC,
            "WethOptionPoolVault",
            "ETHCC",
            ConstantsMainnet.WETH_UNI_POOL
        );
        require(address(opHook) == hookAddress, "PointsHookScript: hook address mismatch");



    }
}