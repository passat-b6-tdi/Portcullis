import { formatUnits } from "viem";

export function shortHex(h: string, lead = 6, tail = 4): string {
  if (!h || h.length <= lead + tail + 2) return h;
  return `${h.slice(0, lead + 2)}…${h.slice(-tail)}`;
}

export function fmtValue(v: bigint | string, decimals = 18): string {
  const n = typeof v === "string" ? BigInt(v) : v;
  const s = formatUnits(n, decimals);
  const [int, frac = ""] = s.split(".");
  const grouped = int.replace(/\B(?=(\d{3})+(?!\d))/g, ",");
  return frac ? `${grouped}.${frac.slice(0, 2)}` : grouped;
}

export function fmtAge(tsSec: number | string): string {
  const t = typeof tsSec === "string" ? Number(tsSec) : tsSec;
  const d = Math.max(0, Math.floor(Date.now() / 1000) - t);
  if (d < 60) return `${d}s ago`;
  if (d < 3600) return `${Math.floor(d / 60)}m ago`;
  if (d < 86400) return `${Math.floor(d / 3600)}h ago`;
  return `${Math.floor(d / 86400)}d ago`;
}

export const TRIP_REASONS = [
  "NONE",
  "BINDING",
  "BOUNDS",
  "REPLAY",
  "NONCE_GAP",
  "RATE_LIMIT",
  "VOLUME_SPIKE",
  "POLICY",
  "EXPIRED",
  "POLICY_HOLD"
] as const;

export function reasonLabel(code: number): string {
  return TRIP_REASONS[code] ?? "UNKNOWN";
}

const LATCHING = new Set(["RATE_LIMIT", "VOLUME_SPIKE", "POLICY"]);

export function isLatching(reason: string): boolean {
  return LATCHING.has(reason);
}

export function reasonClass(reason: string): string {
  if (reason === "NONE") return "bg-emerald-500/15 text-emerald-300 border-emerald-500/30";
  if (LATCHING.has(reason)) return "bg-red-500/15 text-red-300 border-red-500/30";
  return "bg-amber-500/15 text-amber-300 border-amber-500/30";
}

export type Tone = "ok" | "bad" | "warn" | "neutral";

export function verdict(cleared: boolean, reason: string): {
  label: string;
  tone: Tone;
  chip: string;
  edge: string;
} {
  if (cleared) {
    return {
      label: "PASS",
      tone: "ok",
      chip: "border-brand/30 bg-brand/10 text-brand",
      edge: "border-l-brand/60"
    };
  }
  if (LATCHING.has(reason)) {
    return {
      label: reason,
      tone: "bad",
      chip: "border-danger/30 bg-danger/10 text-danger",
      edge: "border-l-danger/60"
    };
  }
  return {
    label: reason,
    tone: "warn",
    chip: "border-warn/30 bg-warn/10 text-warn",
    edge: "border-l-warn/60"
  };
}
