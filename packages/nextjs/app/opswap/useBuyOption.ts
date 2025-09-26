import { PERMIT2_ADDRESS, UNIVERSAL_ROUTER, USDC_TOKEN } from "./constants";
import permit2Abi from "./permit2.json";
import { useContract } from "./useContract";
import { CommandType, RoutePlanner } from "@uniswap/universal-router-sdk";
import { Actions, SwapExactInSingle, V4Planner } from "@uniswap/v4-sdk";
import { parseUnits } from "viem";
import { useWriteContract } from "wagmi";

export const useBuyOption = () => {
  const contract = useContract();
  const { writeContract } = useWriteContract();

  const buyOptions = (amount: number, optionAddress: string) => {
    const zeroForOne = USDC_TOKEN.address < optionAddress;
    const currency0 = zeroForOne ? USDC_TOKEN.address : optionAddress;
    const currency1 = zeroForOne ? optionAddress : USDC_TOKEN.address;
    const currentConfig: SwapExactInSingle = {
      poolKey: {
        currency0: currency0,
        currency1: currency1,
        fee: 0,
        tickSpacing: 32767,
        hooks: contract?.OpHook.address as `0x${string}`,
      },
      zeroForOne: zeroForOne, // The direction of swap is USDC to ETH. Change it to 'false' for the reverse direction
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

    const currencyTake = zeroForOne ? currentConfig.poolKey.currency1 : currentConfig.poolKey.currency0;
    const currencySettle = zeroForOne ? currentConfig.poolKey.currency0 : currentConfig.poolKey.currency1;

    planner.addAction(Actions.SWAP_EXACT_IN_SINGLE, [currentConfig]);
    planner.addAction(Actions.SETTLE_ALL, [currencySettle, currentConfig.amountIn]);
    planner.addAction(Actions.TAKE_ALL, [currencyTake, currentConfig.amountOutMinimum]);

    const encodedActions = planner.finalize();
    routePlanner.addCommand(CommandType.V4_SWAP, [planner.actions, planner.params]);
    const approveAbi = [
      {
        constant: false,
        inputs: [
          {
            name: "_spender",
            type: "address",
          },
          {
            name: "_value",
            type: "uint256",
          },
        ],
        name: "approve",
        outputs: [
          {
            name: "",
            type: "bool",
          },
        ],
        payable: false,
        stateMutability: "nonpayable",
        type: "function",
      },
    ];
    const expiry = Math.floor(Date.now() / 1000) + 36000;
    writeContract({
      address: USDC_TOKEN.address,
      abi: approveAbi,
      functionName: "approve",
      args: [PERMIT2_ADDRESS, currentConfig.amountIn],
    });
    writeContract({
      address: PERMIT2_ADDRESS,
      abi: permit2Abi,
      functionName: "approve",
      args: [USDC_TOKEN.address, UNIVERSAL_ROUTER, currentConfig.amountIn, expiry], // expiration is uint48
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
