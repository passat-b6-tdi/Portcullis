import { createPublicClient, http, type Abi } from "viem";
import { CHAIN, GUARD_ADDRESS, RPC_URL } from "./config";

export const publicClient = createPublicClient({ chain: CHAIN, transport: http(RPC_URL) });

export const GUARD_ABI = [
  { type: "function", name: "paused", stateMutability: "view", inputs: [], outputs: [{ type: "bool" }] },
  {
    type: "function",
    name: "isGuardian",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ type: "bool" }]
  },
  {
    type: "function",
    name: "bounds",
    stateMutability: "view",
    inputs: [],
    outputs: [
      { name: "minValue", type: "uint256" },
      { name: "maxValue", type: "uint256" }
    ]
  },
  {
    type: "function",
    name: "volumeState",
    stateMutability: "view",
    inputs: [],
    outputs: [
      { name: "oracle", type: "address" },
      { name: "spikeFactorBps", type: "uint256" },
      { name: "warmup", type: "uint256" }
    ]
  },
  { type: "function", name: "clear", stateMutability: "nonpayable", inputs: [], outputs: [] },
  {
    type: "event",
    name: "SentinelTripped",
    inputs: [
      { name: "reason", type: "uint8", indexed: false },
      { name: "messageId", type: "bytes32", indexed: true },
      { name: "reporter", type: "address", indexed: true }
    ]
  }
] as const satisfies Abi;

export interface GuardStatus {
  paused: boolean;
  minValue: bigint;
  maxValue: bigint;
  spikeFactorBps: bigint;
  warmup: bigint;
}

export async function readGuardStatus(): Promise<GuardStatus> {
  const [paused, bounds, volume] = await Promise.all([
    publicClient.readContract({ address: GUARD_ADDRESS, abi: GUARD_ABI, functionName: "paused" }),
    publicClient.readContract({ address: GUARD_ADDRESS, abi: GUARD_ABI, functionName: "bounds" }),
    publicClient.readContract({ address: GUARD_ADDRESS, abi: GUARD_ABI, functionName: "volumeState" })
  ]);
  return {
    paused,
    minValue: bounds[0],
    maxValue: bounds[1],
    spikeFactorBps: volume[1],
    warmup: volume[2]
  };
}

export function readIsGuardian(account: `0x${string}`): Promise<boolean> {
  return publicClient.readContract({
    address: GUARD_ADDRESS,
    abi: GUARD_ABI,
    functionName: "isGuardian",
    args: [account]
  });
}
