// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IVolumeVerdictOracle } from "../interfaces/IVolumeVerdictOracle.sol";
import { IPreSettlementPolicy } from "../interfaces/IPreSettlementPolicy.sol";

/// @title Settlement message evaluated before an adapter releases value.
struct SettlementMessage {
    /// @notice Guardian-enrolled source identifier, such as an organization subname's namehash.
    bytes32 srcId;
    /// @notice Beneficiary that receives the settlement on this chain.
    address recipient;
    /// @notice Settlement asset on this chain.
    address token;
    /// @notice Settlement amount expressed in the token's native decimals.
    uint256 value;
    /// @notice Per-source sequence number, which must be exactly one greater than the last accepted nonce.
    uint256 appNonce;
    /// @notice Unix timestamp after which the message is rejected.
    uint256 deadline;
}

/// @title Reason a settlement was rejected by the guard.
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

/// @title Per-source history used by the local volume-spike detector.
struct VolumeStat {
    /// @notice Running mean during warmup, then EMA, of accepted 18-decimal-normalized values.
    uint256 baseline;
    /// @notice Number of accepted messages included in the baseline.
    uint256 observations;
}

/// @title Storage backing PortcullisGuard and its delegated checking library.
/// @dev The guard invokes PortcullisChecks by DELEGATECALL, so the library reads and commits this storage in the guard's context.
struct GuardState {
    /// @notice Whether the circuit breaker currently rejects all adapter submissions.
    bool paused;
    /// @notice Whether each source identifier has been approved by a guardian.
    mapping(bytes32 => bool) enrolled;
    /// @notice Inclusive lower value bound in 18-decimal-normalized units.
    uint256 minValue;
    /// @notice Inclusive upper value bound in 18-decimal-normalized units.
    uint256 maxValue;
    /// @notice Per-token normalization multiplier; zero means that token is not allowed.
    mapping(address => uint256) tokenScale;
    /// @notice Whether a message digest has already been accepted.
    mapping(bytes32 => bool) seen;
    /// @notice Last accepted application nonce for each source.
    mapping(bytes32 => uint256) lastNonce;
    /// @notice Token-bucket capacity in 18-decimal-normalized units; zero disables rate limiting.
    uint256 rateCapacity;
    /// @notice Token-bucket refill rate per second in 18-decimal-normalized units.
    uint256 rateRefillPerSec;
    /// @notice Unrefilled token-bucket allowance remaining at lastRefill.
    uint256 tokens;
    /// @notice Timestamp from which token-bucket refill is calculated.
    uint256 lastRefill;
    /// @notice Optional external volume oracle; when present it replaces local EMA volume checks.
    IVolumeVerdictOracle volumeOracle;
    /// @notice Largest permitted local volume as basis points of the source baseline, where 30,000 means 3.0x.
    uint256 spikeFactorBps;
    /// @notice Number of accepted source messages required before local spike checks start.
    uint256 warmup;
    /// @notice Local rolling volume history for each source.
    mapping(bytes32 => VolumeStat) volume;
    /// @notice Optional confidential pre-settlement policy; a zero address skips this detector.
    IPreSettlementPolicy policy;
}
