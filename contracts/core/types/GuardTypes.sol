// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IVolumeVerdictOracle } from "../interfaces/IVolumeVerdictOracle.sol";
import { IPreSettlementPolicy } from "../interfaces/IPreSettlementPolicy.sol";

struct SettlementMessage {
    bytes32 srcId; // source identifier (e.g. namehash of an org subname)
    address recipient; // beneficiary on this chain
    address token; // settlement asset on this chain
    uint256 value; // settlement amount
    uint256 appNonce; // must equal lastNonce[srcId] + 1
    uint256 deadline; // unix seconds; message rejected once passed
}

enum TripReason {
    NONE,
    BINDING,
    BOUNDS,
    REPLAY,
    NONCE_GAP,
    RATE_LIMIT,
    VOLUME_SPIKE,
    POLICY,
    EXPIRED,
    POLICY_HOLD
}

struct GuardState {
    bool paused;
    mapping(bytes32 => bool) enrolled; // srcId => guardian-approved source
    // bounds
    uint256 minValue;
    uint256 maxValue;
    mapping(address => bool) allowedToken;
    // replay / ordering
    mapping(bytes32 => bool) seen; // messageId => consumed
    mapping(bytes32 => uint256) lastNonce; // srcId => last accepted appNonce
    // rate limit (token bucket); capacity 0 => disabled
    uint256 rateCapacity;
    uint256 rateRefillPerSec;
    uint256 tokens; // allowance remaining as of lastRefill
    uint256 lastRefill;
    // volume policy: oracle set => delegate, else local EMA; both 0 => disabled
    IVolumeVerdictOracle volumeOracle;
    uint256 baseline; // EMA of accepted value (local mode)
    uint256 spikeFactorBps; // 30_000 => allow up to 3.0x baseline
    uint256 observations;
    uint256 warmup; // no spike check until observations >= warmup
    // confidential pre-settlement policy (CRE); address(0) => detector skipped
    IPreSettlementPolicy policy;
}
