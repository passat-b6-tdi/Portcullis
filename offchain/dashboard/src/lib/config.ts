import { defineChain } from "viem";
import { sepolia } from "viem/chains";

export const GUARD_ADDRESS = (process.env.NEXT_PUBLIC_GUARD_ADDRESS ??
  "0xE59474b146d750022c5E3C9376d74D0Ca31D7008") as `0x${string}`;

export const RECEIVER_ADDRESS = (process.env.NEXT_PUBLIC_RECEIVER_ADDRESS ??
  "0x48a04458bB4EaaD6D4902D30fFd8C20B6D2c55B9") as `0x${string}`;

export const SUBGRAPH_URL =
  process.env.NEXT_PUBLIC_SUBGRAPH_URL ??
  "https://api.studio.thegraph.com/query/59239/portcullis/latest";
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
