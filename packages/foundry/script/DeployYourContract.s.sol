// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import "../contracts/OpHook.sol";
import {HookMiner} from "lib/uniswap-hooks/lib/v4-periphery/src/utils/HookMiner.sol";

/**
 * @notice Deploy script for OpHook contract
 * @dev Inherits ScaffoldETHDeploy which:
 *      - Includes forge-std/Script.sol for deployment
 *      - Includes ScaffoldEthDeployerRunner modifier
 *      - Provides `deployer` variable
 * Example:
 * yarn deploy --file DeployYourContract.s.sol  # local anvil chain
 * yarn deploy --file DeployYourContract.s.sol --network optimism # live network (requires keystore)
 */
contract DeployYourContract is ScaffoldETHDeploy {
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    /**
     * @dev Deployer setup based on `ETH_KEYSTORE_ACCOUNT` in `.env`:
     *      - Uses Anvil's account #9 (0xa0Ee7A142d267C1f36714E4a8F75612F20a79720), no password prompt
     *      - "scaffold-eth-custom": requires password used while creating keystore
     *
     * Note: Must use ScaffoldEthDeployerRunner modifier to:
     *      - Setup correct `deployer` account and fund it
     *      - Export contract addresses & ABIs to `nextjs` packages
     */
    function run() external ScaffoldEthDeployerRunner {
        // For testing purposes, we'll use a mock pool manager address
        // In production, you would deploy or use an existing PoolManager
        address mockPoolManager = address(0x1234567890123456789012345678901234567890);

        // OpHook only uses beforeSwap permission
        uint160 flags = uint160(0x80); // BEFORE_SWAP_FLAG = 1 << 7 = 128 = 0x80

        bytes memory constructorArgs = abi.encode(address(mockPoolManager));

        // Mine a salt that will produce a hook address with the correct flags
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            flags,
            type(OpHook).creationCode,
            constructorArgs
        );

        console.log("Deploying OpHook to address:", hookAddress);
        console.log("Using salt:", uint256(salt));

        // Deploy the hook using CREATE2
        OpHook hook = new OpHook{salt: salt}(IPoolManager(address(mockPoolManager)));
        require(address(hook) == hookAddress, "OpHook: hook address mismatch");

        console.log("OpHook deployed successfully at:", address(hook));
    }
}
