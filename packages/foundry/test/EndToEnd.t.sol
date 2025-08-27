// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {IOptionToken} from "../contracts/IOptionToken.sol";
import {IPermit2} from "../contracts/IPermit2.sol";
import {OptionPrice} from "../contracts/OptionPrice.sol";
import {OpHook} from "../contracts/OpHook.sol";

// Uniswap V4 imports
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {SwapParams} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {HookMiner} from "lib/uniswap-hooks/lib/v4-periphery/src/utils/HookMiner.sol";
import {Constants} from "@uniswap/v4-core/test/utils/Constants.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";

// import {Deployers} from "v4-core/test/utils/Deployers.sol";

contract TestERC20 is IERC20 {
            string public name;
            string public symbol;
            uint8 public decimals = 18;
            uint256 public override totalSupply;
            mapping(address => uint256) public override balanceOf;
            mapping(address => mapping(address => uint256)) public override allowance;

            constructor(string memory _name, string memory _symbol) {
                name = _name;
                symbol = _symbol;
            }

            function transfer(address to, uint256 amount) public override returns (bool) {
                require(balanceOf[msg.sender] >= amount, "insufficient");
                balanceOf[msg.sender] -= amount;
                balanceOf[to] += amount;
                emit Transfer(msg.sender, to, amount);
                return true;
            }

            function approve(address spender, uint256 amount) public override returns (bool) {
                allowance[msg.sender][spender] = amount;
                emit Approval(msg.sender, spender, amount);
                return true;
            }

            function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
                require(balanceOf[from] >= amount, "insufficient");
                require(allowance[from][msg.sender] >= amount, "not allowed");
                allowance[from][msg.sender] -= amount;
                balanceOf[from] -= amount;
                balanceOf[to] += amount;
                emit Transfer(from, to, amount);
                return true;
            }

            function mint(address to, uint256 amount) public {
                balanceOf[to] += amount;
                totalSupply += amount;
                emit Transfer(address(0), to, amount);
            }

        }


contract EndToEndTest is Test {
    // Mainnet addresses
    address constant MAINNET_PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
    
    // Test addresses (these would be deployed option tokens in a real scenario)
    address constant TEST_OPTION_TOKEN = 0x1234567890123456789012345678901234567890;
    bytes constant ZERO_BYTES = new bytes(0);
    OptionPrice public optionPrice;
    
    // Test users
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    TestERC20 public tokenA;
    TestERC20 public tokenB;

    address public mainnetPoolManager = 0x000000000004444c5dc75cB358380D2e3dE08A90;
    address public testnetPoolManager = 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;
    PoolManager public poolManager;
    PoolSwapTest public swapRouter;

    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);
    address constant WETH_UNI_POOL = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640;

    function setUp() public {
        // For testing without forking mainnet, we'll use a local environment
        // In production, you would use: vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 19000000);
        
        // Deploy the option price contract for testing
        optionPrice = new OptionPrice(WETH_UNI_POOL);
        // fork mainnet here
        // vm.createSelectFork("https://rpc.flashbots.net");
        vm.createSelectFork("https://ethereum-sepolia-rpc.publicnode.com");

        // Deployers.deployFreshManagerAndRouters();

        // Deploy two ERC20 tokens and allocate 10 of each to the test user (alice)
        // We'll use a simple ERC20 implementation for testing

        // Minimal ERC20 for testing

        poolManager = new PoolManager(address(this));
        swapRouter = new PoolSwapTest(poolManager);
        

        // Deploy two test ERC20 tokens
        tokenA = new TestERC20("TokenA", "TKA");
        tokenB = new TestERC20("TokenB", "TKB");

        // Mint 10 tokens (with 18 decimals) to alice
        tokenA.mint(alice, 10 ether);
        tokenB.mint(alice, 10 ether);

        
        // Fund test users
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
    }


    function test_HookSwap() public {




        bytes memory constructorArgs = abi.encode(address(poolManager));

        // Mine a salt that will produce a hook address with the correct flags
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER,
            uint160(Hooks.BEFORE_SWAP_FLAG),
            type(OpHook).creationCode,
            constructorArgs
        );

        console.log("Deploying OpHook to address:", hookAddress);
        console.log("Using salt:", uint256(salt));

        address token1 = address(tokenA) < address(tokenB) ? address(tokenA) : address(tokenB);
        address token2 = address(tokenA) < address(tokenB) ? address(tokenB) : address(tokenA);

        // Deploy the hook using CREATE2
        vm.startBroadcast();
        OpHook opHook = new OpHook{salt: salt}(poolManager, MAINNET_PERMIT2, IERC20(token1), "WethOptionPoolVault", "ETHCC", WETH_UNI_POOL);
        poolManager.unlock("");
        poolManager.initialize(PoolKey({
            currency0: Currency.wrap(token1),
            currency1: Currency.wrap(token2),
            fee: 3000,
            hooks: opHook,
            tickSpacing: 60
        }), 1e18);

        PoolSwapTest.TestSettings memory testSettings = PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});

        // swapRouter.swap(PoolKey({
        //     currency0: Currency.wrap(token1),
        //     currency1: Currency.wrap(token2),
        //     fee: 3000,
        //     tickSpacing: 60,
        //     hooks: IHooks(address(opHook))  
        // }), SwapParams({
        //     zeroForOne: true,
        //     amountSpecified: -1e18,
        //     sqrtPriceLimitX96: 0
        // }), testSettings, ZERO_BYTES);


        swapRouter.swap(PoolKey({
            currency0: Currency.wrap(token1),
            currency1: Currency.wrap(token2),
            fee: 3000,
            hooks: opHook,
            tickSpacing: 60
        }), SwapParams({
            zeroForOne: true,
            amountSpecified: -1e18,
            sqrtPriceLimitX96: 0
        }), testSettings, ZERO_BYTES);

        vm.stopBroadcast();
    }

}
