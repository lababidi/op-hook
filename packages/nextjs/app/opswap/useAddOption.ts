import { useContract } from "./useContract";
import { useWriteContract } from "wagmi";

export const useAddOption = () => {
  const contract = useContract();
  const { data: result, writeContractAsync } = useWriteContract();

  const addOptions = async (optionAddress: string) => {
    console.log("Add OptionAddress:", optionAddress);
    const result_ = await writeContractAsync({
      address: contract?.OpHook.address as `0x${string}`,
      abi: contract?.OpHook.abi,
      functionName: "initPool",
      args: [optionAddress as `0x${string}`, 0],
    });
    console.log("Add Option Result:", result_);
    console.log("Add Option Result:", result);
  };

  return addOptions;
};
