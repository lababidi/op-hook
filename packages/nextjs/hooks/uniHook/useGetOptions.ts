import { useContract } from "./useContract";
import { Address } from "viem";
import { useReadContract } from "wagmi";

export type CurrentOptionPrice = {
  collateral: Address;
  optionToken: Address;
  price: bigint;
  collateralPrice: bigint;
};

export const useGetOptions = () => {
  const contract = useContract();
  const abi = contract?.OpHook?.abi;

  const {
    data: options,
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

  console.log("options", options);
  console.log("error", error);

  //   const {
  //     data: allOptions,
  //     error: error_,
  //     refetch: refetchNames,
  //   } = useReadContracts({
  //     contracts: ((options as CurrentOptionPrice[]) || [])
  //       .map((option: CurrentOptionPrice) =>
  //         option
  //           ? {
  //               address: option.optionToken,
  //               abi: erc20Abi,
  //               functionName: "name",
  //             }
  //           : undefined,
  //       )
  //       .filter(option => option !== undefined),
  //     query: {
  //       enabled: !!createdOptions,
  //     },
  //   });

  //   const optionList = (allOptions || []).map((option, index) => ({
  //     name: option.result as string,
  //     address: ((createdOptions as CurrentOptionPrice[]) || [])[index]?.optionToken,
  //   }));

  const refetchAll = () => {
    refetch();
    // refetchNames();
  };

  return {
    options,
    // createdOptions,
    // allOptions,
    // optionList,
    // error: error_,
    refetch: refetchAll,
  };
};
