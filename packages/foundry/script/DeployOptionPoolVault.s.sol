// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../contracts/OptionPoolVault.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for deployment
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10**decimals());
    }
}

// Mock option pool for deployment
contract MockOptionPool {
    address public vault;
    
    constructor(address _vault) {
        vault = _vault;
    }
}

contract DeployOptionPoolVault is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy mock underlying token (replace with actual token in production)
        MockERC20 underlying = new MockERC20("Test Token", "TEST");

        // Deploy mock option pool (replace with actual option pool in production)
        MockOptionPool optionPool = new MockOptionPool(address(0));

        // Deploy the vault
        OptionPoolVault vault = new OptionPoolVault(
            underlying,
            "Option Pool Vault",
            "opVAULT",
            msg.sender, // fee recipient
            100, // 1% fee rate
            address(optionPool)
        );

        // Update option pool to point to vault
        optionPool = new MockOptionPool(address(vault));

        // Update vault with new option pool address
        vault.updateOptionPool(address(optionPool));

        // Fund vault with initial liquidity
        underlying.transfer(address(vault), 10000 * 10**underlying.decimals());

        vm.stopBroadcast();
    }
}
