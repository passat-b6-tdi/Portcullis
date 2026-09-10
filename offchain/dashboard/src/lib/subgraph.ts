import { SUBGRAPH_URL } from "./config";

export interface Settlement {
  id: string;
  srcId: string;
  recipient: string;
  token: string;
  value: string;
  cleared: boolean;
  reason: string;
  blockTimestamp: string;
  txHash: string;
}

export interface SentinelEvent {
  id: string;
  kind: string;
  reason: string | null;
  messageId: string | null;
  actor: string;
  blockTimestamp: string;
  txHash: string;
}

export interface GuardConfig {
  id: string;
  minValue: string | null;
  maxValue: string | null;
  rateCapacity: string | null;
  rateRefillPerSec: string | null;
  spikeFactorBps: string | null;
  warmup: string | null;
  policy: string | null;
  guardian: string | null;
  paused: boolean;
  lastReason: string | null;
  updatedAt: string;
}

export interface Overview {
  settlements: Settlement[];
  sentinelEvents: SentinelEvent[];
  config: GuardConfig | null;
  sources: { id: string; enrolled: boolean }[];
  tokens: { id: string; allowed: boolean; decimals: number }[];
  payoutCount: number;
  rejectionCount: number;
  indexedBlock: number | null;
  indexingErrors: boolean;
}

const QUERY = `{
  _meta { block { number } hasIndexingErrors }
  settlements(first: 50, orderBy: blockTimestamp, orderDirection: desc) {
    id srcId recipient token value cleared reason blockTimestamp txHash
  }
  sentinelEvents(first: 25, orderBy: blockTimestamp, orderDirection: desc) {
    id kind reason messageId actor blockTimestamp txHash
  }
  guardConfig(id: "guard") {
    id minValue maxValue rateCapacity rateRefillPerSec spikeFactorBps warmup
    policy guardian paused lastReason updatedAt
  }
  sources(first: 50) { id enrolled }
  allowedTokens(first: 50) { id allowed decimals }
  payouts(first: 1000) { id }
  rejections(first: 1000) { id }
}`;

export async function fetchOverview(): Promise<Overview> {
  if (!SUBGRAPH_URL) throw new Error("NEXT_PUBLIC_SUBGRAPH_URL not set");
  const res = await fetch(SUBGRAPH_URL, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ query: QUERY })
  });
  const json = await res.json();
  if (json.errors) throw new Error(json.errors[0]?.message ?? "subgraph error");
  const d = json.data;
  return {
    settlements: d.settlements ?? [],
    sentinelEvents: d.sentinelEvents ?? [],
    config: d.guardConfig ?? null,
    sources: d.sources ?? [],
    tokens: d.allowedTokens ?? [],
    payoutCount: (d.payouts ?? []).length,
    rejectionCount: (d.rejections ?? []).length,
    indexedBlock: d._meta?.block?.number ?? null,
    indexingErrors: !!d._meta?.hasIndexingErrors
  };
}
