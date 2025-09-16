import { useChainId } from "wagmi";
import deployedContracts from "~~/contracts/deployedContracts";

export const useContract = () => {
  const chainId = useChainId();
  const contract = deployedContracts[chainId as keyof typeof deployedContracts];
  if (!contract) {
    console.warn(`No contracts found for chain ID ${chainId}`);
  }
  return contract;
};
