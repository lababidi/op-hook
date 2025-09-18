import { useContract } from "./opswap/useContract";
import { Address } from "viem";
import { useReadContract } from "wagmi";

export const useGetOptions = () => {
  const contract = useContract();
  const { data: prices, error } = useReadContract({
    address: contract?.OpHook.address as Address,
    abi: contract?.OpHook.abi,
    functionName: "getPrices",
  });
  if (!contract) {
    console.warn(`No contracts found`);
  }
  //   const prices = data?.[0] || [];
  return { prices, error };
};
