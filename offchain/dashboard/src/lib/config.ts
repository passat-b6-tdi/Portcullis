import { defineChain } from "viem";
import { sepolia } from "viem/chains";

export const GUARD_ADDRESS = (process.env.NEXT_PUBLIC_GUARD_ADDRESS ??
  "0x0000000000000000000000000000000000000000") as `0x${string}`;

export const RECEIVER_ADDRESS = (process.env.NEXT_PUBLIC_RECEIVER_ADDRESS ??
  "0x0000000000000000000000000000000000000000") as `0x${string}`;

export const SUBGRAPH_URL = process.env.NEXT_PUBLIC_SUBGRAPH_URL ?? "";
export const RPC_URL =
  process.env.NEXT_PUBLIC_RPC_URL ?? "https://ethereum-sepolia-rpc.publicnode.com";
export const PRIVY_APP_ID = process.env.NEXT_PUBLIC_PRIVY_APP_ID ?? "";
export const EXPLORER =
  process.env.NEXT_PUBLIC_EXPLORER ?? "https://sepolia.etherscan.io";

const CHAIN_ID = Number(process.env.NEXT_PUBLIC_CHAIN_ID ?? "11155111");

export const CHAIN =
  CHAIN_ID === sepolia.id
    ? sepolia
    : defineChain({
        id: CHAIN_ID,
        name: `chain-${CHAIN_ID}`,
        nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
        rpcUrls: { default: { http: [RPC_URL] } }
      });
