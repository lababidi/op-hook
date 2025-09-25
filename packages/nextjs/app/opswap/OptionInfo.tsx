import React from "react";
import { erc20Abi } from "viem";
import { useReadContract } from "wagmi";

// Replace with your actual token address prop or value
type OptionInfoProps = {
  option: `0x${string}`;
};

export const OptionInfo: React.FC<OptionInfoProps> = ({ option }) => {
  const { data: name } = useReadContract({
    address: option,
    abi: erc20Abi,
    functionName: "name",
  });

  const [collateral, consideration, expiration, price] = (name || "-----").split("-").slice(1);

  return (
    <div>
      <div>
        <strong style={{ fontWeight: "bold" }}>{collateral ?? "Loading..."}</strong>
      </div>
      <div>
        <strong>Strike:</strong> {BigInt(price) / BigInt(1e18)} {consideration ?? "Loading..."}
      </div>
      <div>
        <strong>Exp:</strong> {expiration ?? "Loading..."}
      </div>
      <div>
        {option ? `${option.substring(0, 6)}...${option.substring(option.length - 4)}` : "Loading..."}
        <button
          onClick={() => navigator.clipboard.writeText(option)}
          style={{ marginLeft: "8px", cursor: "pointer" }}
          title="Copy address to clipboard"
        >
          📋
        </button>
      </div>
    </div>
  );
};
