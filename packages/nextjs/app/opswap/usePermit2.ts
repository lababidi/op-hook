import { PERMIT2_ADDRESS } from "./constants";
import { PermitTransferFrom, SignatureTransfer } from "@uniswap/permit2-sdk";
import { Address, recoverAddress } from "viem";
import { useChainId, useSignTypedData } from "wagmi";

const generateNonce = () => {
  const now = BigInt(Date.now()); // milliseconds
  const rand = BigInt(Math.floor(Math.random() * 1e6)); // up to ~20 bits
  const nonce = (now << 20n) | rand; // shift timestamp to make room for rand bits
  return nonce & ((1n << 48n) - 1n); // ensure it’s uint48
};

export const usePermit2 = (token: Address, spender: Address) => {
  const { signTypedDataAsync } = useSignTypedData();
  const chainId = useChainId();

  const getPermitSignature = async (amount: bigint) => {
    const PERMIT_EXPIRATION = 30 * 60 * 1000; // 30 minutes in milliseconds
    const nonce = generateNonce();

    /**
     * Converts an expiration (in milliseconds) to a deadline (in seconds) suitable for the EVM.
     * Permit2 expresses expirations as deadlines, but JavaScript usually uses milliseconds,
     * so this is provided as a convenience function.
     */
    function toDeadline(expiration: number): number {
      return Math.floor((Date.now() + expiration) / 1000);
    }

    const permit: PermitTransferFrom = {
      permitted: {
        token: token,
        amount: amount,
      },
      spender: spender,
      nonce: nonce ?? 0n,
      deadline: toDeadline(PERMIT_EXPIRATION),
    };

    const { domain, types, values } = SignatureTransfer.getPermitData(permit, PERMIT2_ADDRESS, chainId);
    const digest = SignatureTransfer.hash(permit, PERMIT2_ADDRESS, chainId);
    const signature = await signTypedDataAsync({
      domain: domain as any,
      types: types as any,
      primaryType: "PermitTransferFrom",
      message: values as any,
    });

    const transferDetails = {
      to: spender,
      requestedAmount: amount,
    };

    const recoveredAddress = await recoverAddress({
      hash: digest as `0x${string}`,
      signature,
    });
    console.log("recoveredAddress", recoveredAddress);
    console.log("nonce", nonce);

    return { permit, signature, transferDetails };
  };

  return { getPermitSignature };
};
