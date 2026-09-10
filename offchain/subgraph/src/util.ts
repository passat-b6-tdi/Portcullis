import { BigInt } from "@graphprotocol/graph-ts";
import { GuardConfig } from "../generated/schema";

export const GUARD_ID = "guard";

export function tripReason(code: i32): string {
  const names = [
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
  ];
  if (code < 0 || code >= names.length) return "UNKNOWN";
  return names[code];
}

export function loadConfig(updatedAt: BigInt): GuardConfig {
  let cfg = GuardConfig.load(GUARD_ID);
  if (cfg == null) {
    cfg = new GuardConfig(GUARD_ID);
    cfg.paused = false;
  }
  cfg.updatedAt = updatedAt;
  return cfg as GuardConfig;
}
