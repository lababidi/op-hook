// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {ScaffoldETHDeploy} from "./DeployHelpers.s.sol";

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";

import {OpHook} from "../contracts/OpHook.sol";
import {ConstantsUnichain} from "../contracts/ConstantsUnichain.sol";



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