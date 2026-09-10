import { ethereum, Bytes } from "@graphprotocol/graph-ts";
import {
  SettlementInspected,
  SentinelTripped,
  SentinelCleared,
  BoundsSet,
  RateSet,
  VolumePolicySet,
  PolicySet,
  GuardianTransferred,
  SourceEnrolled,
  TokenAllowed
} from "../generated/PortcullisGuard/PortcullisGuard";
import {
  Settlement,
  SentinelEvent,
  Source,
  AllowedToken
} from "../generated/schema";
import { tripReason, loadConfig } from "./util";

function evId(event: ethereum.Event): Bytes {
  return event.transaction.hash.concatI32(event.logIndex.toI32());
}

export function handleSettlementInspected(event: SettlementInspected): void {
  const s = new Settlement(evId(event));
  s.messageId = event.params.messageId;
  s.srcId = event.params.srcId;
  s.recipient = event.params.recipient;
  s.token = event.params.token;
  s.value = event.params.value;
  s.cleared = event.params.cleared;
  s.reason = tripReason(event.params.reason);
  s.detectorMask = event.params.detectorMask;
  s.blockNumber = event.block.number;
  s.blockTimestamp = event.block.timestamp;
  s.txHash = event.transaction.hash;
  s.save();
}

export function handleSentinelTripped(event: SentinelTripped): void {
  const e = new SentinelEvent(evId(event));
  e.kind = "TRIPPED";
  e.reason = tripReason(event.params.reason);
  e.messageId = event.params.messageId;
  e.actor = event.params.reporter;
  e.blockNumber = event.block.number;
  e.blockTimestamp = event.block.timestamp;
  e.txHash = event.transaction.hash;
  e.save();

  const cfg = loadConfig(event.block.timestamp);
  cfg.paused = true;
  cfg.lastReason = tripReason(event.params.reason);
  cfg.save();
}

export function handleSentinelCleared(event: SentinelCleared): void {
  const e = new SentinelEvent(evId(event));
  e.kind = "CLEARED";
  e.actor = event.params.guardian;
  e.blockNumber = event.block.number;
  e.blockTimestamp = event.block.timestamp;
  e.txHash = event.transaction.hash;
  e.save();

  const cfg = loadConfig(event.block.timestamp);
  cfg.paused = false;
  cfg.lastReason = null;
  cfg.save();
}

export function handleBoundsSet(event: BoundsSet): void {
  const cfg = loadConfig(event.block.timestamp);
  cfg.minValue = event.params.minValue;
  cfg.maxValue = event.params.maxValue;
  cfg.save();
}

export function handleRateSet(event: RateSet): void {
  const cfg = loadConfig(event.block.timestamp);
  cfg.rateCapacity = event.params.capacity;
  cfg.rateRefillPerSec = event.params.refillPerSec;
  cfg.save();
}

export function handleVolumePolicySet(event: VolumePolicySet): void {
  const cfg = loadConfig(event.block.timestamp);
  cfg.volumeOracle = event.params.oracle;
  cfg.spikeFactorBps = event.params.spikeFactorBps;
  cfg.warmup = event.params.warmup;
  cfg.save();
}

export function handlePolicySet(event: PolicySet): void {
  const cfg = loadConfig(event.block.timestamp);
  cfg.policy = event.params.policy;
  cfg.save();
}

export function handleGuardianTransferred(event: GuardianTransferred): void {
  const cfg = loadConfig(event.block.timestamp);
  cfg.guardian = event.params.to;
  cfg.save();
}

export function handleSourceEnrolled(event: SourceEnrolled): void {
  let src = Source.load(event.params.srcId);
  if (src == null) src = new Source(event.params.srcId);
  src.enrolled = event.params.enrolled;
  src.updatedAt = event.block.timestamp;
  src.save();
}

export function handleTokenAllowed(event: TokenAllowed): void {
  let t = AllowedToken.load(event.params.token);
  if (t == null) t = new AllowedToken(event.params.token);
  t.allowed = event.params.allowed;
  t.decimals = event.params.decimals;
  t.updatedAt = event.block.timestamp;
  t.save();
}
