import { PERMIT2_ADDRESS, UNIVERSAL_ROUTER, USDC_TOKEN } from "./constants";
import { useContract } from "./useContract";
import { CommandType, RoutePlanner } from "@uniswap/universal-router-sdk";
import { Actions, SwapExactInSingle, V4Planner } from "@uniswap/v4-sdk";
import { parseUnits } from "viem";
import { useWriteContract } from "wagmi";

export const useBuyOption = () => {
  const contract = useContract();
  const { writeContract } = useWriteContract();

  const buyOptions = (amount: number, optionAddress: string) => {
    const currentConfig: SwapExactInSingle = {
      poolKey: {
        currency0: USDC_TOKEN.address,
        currency1: optionAddress,
        fee: 0,
        tickSpacing: 32767,
        hooks: contract?.OpHook.address as `0x${string}`,
      },
      zeroForOne: true, // The direction of swap is USDC to ETH. Change it to 'false' for the reverse direction
      amountIn: parseUnits(amount.toString(), USDC_TOKEN.decimals).toString(),
      amountOutMinimum: "0", // Change according to the slippage desired
      hookData: "0x",
    };

    const UNIVERSAL_ROUTER_ABI = [
      {
        inputs: [
          { internalType: "bytes", name: "commands", type: "bytes" },
          { internalType: "bytes[]", name: "inputs", type: "bytes[]" },
          { internalType: "uint256", name: "deadline", type: "uint256" },
        ],
        name: "execute",
        outputs: [],
        stateMutability: "payable",
        type: "function",
      },
    ];

    const planner = new V4Planner();
    const routePlanner = new RoutePlanner();
    // Set deadline (1 hour from now)
    const deadline = Math.floor(Date.now() / 1000) + 3600;

    planner.addAction(Actions.SWAP_EXACT_IN_SINGLE, [currentConfig]);
    planner.addAction(Actions.SETTLE_ALL, [currentConfig.poolKey.currency1, currentConfig.amountIn]);
    planner.addAction(Actions.TAKE_ALL, [currentConfig.poolKey.currency0, currentConfig.amountOutMinimum]);

    const encodedActions = planner.finalize();
    routePlanner.addCommand(CommandType.V4_SWAP, [planner.actions, planner.params]);
    const erc20abi = ["approve(address,uint256)"];
    writeContract({
      address: USDC_TOKEN.address,
      abi: erc20abi,
      functionName: "approve",
      args: [PERMIT2_ADDRESS, currentConfig.amountIn],
    });
    writeContract({
      address: UNIVERSAL_ROUTER,
      functionName: "execute",
      abi: UNIVERSAL_ROUTER_ABI,
      args: [routePlanner.commands, [encodedActions], deadline],
    });
  };

  return buyOptions;
};
