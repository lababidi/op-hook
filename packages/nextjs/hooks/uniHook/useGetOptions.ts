import { useContract } from "./useContract";
import { Address, erc20Abi } from "viem";
import { useReadContract, useReadContracts } from "wagmi";

type CurrentOptionPrice = {
  collateral: Address;
  optionToken: Address;
  price: bigint;
  collateralPrice: bigint;
};

export const useGetOptions = () => {
  const contract = useContract();
  const abi = contract?.OpHook?.abi;

  const {
    data: createdOptions,
    error,
    refetch,
  } = useReadContract({
    address: contract?.OpHook?.address,
    abi,
    functionName: "getPrices",
    query: {
      enabled: !!contract?.OpHook?.address,
    },
  });

  console.log("createdOptions", createdOptions);
  console.log("error", error);

  const {
    data: allOptions,
    error: error_,
    refetch: refetchNames,
  } = useReadContracts({
    contracts: ((createdOptions as CurrentOptionPrice[]) || [])
      .map((option: CurrentOptionPrice) =>
        option
          ? {
              address: option.optionToken,
              abi: erc20Abi,
              functionName: "name",
            }
          : undefined,
      )
      .filter(option => option !== undefined),
    query: {
      enabled: !!createdOptions,
    },
  });

  const optionList = (allOptions || []).map((option, index) => ({
    name: option.result as string,
    address: ((createdOptions as CurrentOptionPrice[]) || [])[index]?.optionToken,
  }));

  const refetchAll = () => {
    refetch();
    refetchNames();
  };

  return {
    createdOptions,
    allOptions,
    optionList,
    error: error_,
    refetch: refetchAll,
  };
};
