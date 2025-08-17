// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import { TestERC20 } from "./TestToken.sol";

// forge script to deploy two TestERC20 tokens and log their addresses

import { Script, console } from "forge-std/Script.sol";

contract DeployTestTokensScript is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy two test tokens
        TestERC20 tokenA = new TestERC20("TokenA", "TKA");
        TestERC20 tokenB = new TestERC20("TokenB", "TKB");

        // Optionally mint some tokens to the deployer for testing
        address deployer = msg.sender;
        tokenA.mint(deployer, 1000 ether);
        tokenB.mint(deployer, 1000 ether);

        // Log the deployed addresses
        console.log("TestERC20 TokenA deployed at:", address(tokenA));
        console.log("TestERC20 TokenB deployed at:", address(tokenB));

        vm.stopBroadcast();
    }
}

