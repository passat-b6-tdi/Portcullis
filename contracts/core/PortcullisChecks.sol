// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { ECDSA } from "solady/utils/ECDSA.sol";
import { SettlementMessage, GuardState, TripReason, VolumeStat } from "./types/GuardTypes.sol";
import { IIdentityRegistry } from "./interfaces/IIdentityRegistry.sol";

/// @title Delegated settlement validation and commit logic for PortcullisGuard.
/// @dev Calls execute in the guard's storage context through DELEGATECALL. evaluate is view-only; commit is called only after it clears.
library PortcullisChecks {
    /// @notice Bit set in PASS_MASK for a successful source-binding check.
    uint8 internal constant BIT_BINDING = 1 << 0;
    /// @notice Bit set in PASS_MASK for a successful normalized-bounds check.
    uint8 internal constant BIT_BOUNDS = 1 << 1;
    /// @notice Bit set in PASS_MASK for successful replay and nonce-ordering checks.
    uint8 internal constant BIT_REPLAY = 1 << 2;
    /// @notice Bit set in PASS_MASK for a successful rate-limit check.
    uint8 internal constant BIT_RATE = 1 << 3;
    /// @notice Bit set in PASS_MASK for a successful volume check.
    uint8 internal constant BIT_VOLUME = 1 << 4;
    /// @notice Bit set in PASS_MASK for a successful pre-settlement policy check.
    uint8 internal constant BIT_POLICY = 1 << 5;

    /// @notice Mask emitted for a settlement that passed every detector represented by a bit.
    uint8 internal constant PASS_MASK = BIT_BINDING | BIT_BOUNDS | BIT_REPLAY | BIT_RATE | BIT_VOLUME | BIT_POLICY;

    /// @notice CRE code that explicitly permits a settlement.
    uint8 internal constant POLICY_ALLOW = 1;
    /// @notice CRE code that rejects a settlement and causes the guard to latch.
    uint8 internal constant POLICY_DENY = 2;

    /// @notice Basis-point denominator used for local volume thresholds.
    uint256 private constant BPS = 10_000;
    /// @notice Smoothing denominator for the local exponential moving average.
    uint256 private constant EMA_ALPHA = 8;

    /// @notice Computes the chain- and guard-specific settlement digest.
    /// @param m Settlement message to hash.
    /// @return Message digest used for signatures, replay protection, and policy verdicts.
    function digest(SettlementMessage calldata m) internal view returns (bytes32) {
        return keccak256(abi.encode(block.chainid, address(this), m));
    }

    /// @notice Converts a token-native message value to 18-decimal-normalized units.
    /// @dev A zero scale means the token is not allowlisted; multiplication overflow also fails normalization.
    /// @param s Guard storage containing token scales.
    /// @param m Settlement whose value is normalized.
    /// @return norm Normalized value when conversion succeeds.
    /// @return ok Whether the token was allowed and conversion did not overflow.
    function _normalise(GuardState storage s, SettlementMessage calldata m)
        private
        view
        returns (uint256 norm, bool ok)
    {
        uint256 scale = s.tokenScale[m.token];
        if (scale == 0 || m.value > type(uint256).max / scale) return (0, false);
        return (m.value * scale, true);
    }

    /// @notice Runs all settlement detectors in order without mutating guard storage.
    /// @dev Identity, policy, and external volume checks run during this view-only delegated call. A policy DENY is distinct because the guard latches it.
    /// @param s Guard storage.
    /// @param m Proposed settlement message.
    /// @param identity Registry used to resolve the source signing authority.
    /// @param proof Authority signature and any policy or oracle evidence.
    /// @return ok Whether every detector cleared.
    /// @return reason First rejection reason when ok is false.
    function evaluate(
        GuardState storage s,
        SettlementMessage calldata m,
        IIdentityRegistry identity,
        bytes calldata proof
    ) external view returns (bool ok, TripReason reason) {
        if (block.timestamp > m.deadline) return (false, TripReason.EXPIRED); // 0. freshness

        bytes32 mid = digest(m);

        // 1. binding: srcId enrolled by a guardian AND the message signed by its authority
        if (!s.enrolled[m.srcId]) return (false, TripReason.BINDING);
        address authority = identity.resolve(m.srcId);
        if (authority == address(0)) return (false, TripReason.BINDING);
        if (ECDSA.tryRecoverCalldata(ECDSA.toEthSignedMessageHash(mid), proof) != authority) {
            return (false, TripReason.BINDING);
        }

        // 2. bounds: compared in normalised 18 decimal units
        (uint256 norm, bool scaled) = _normalise(s, m);
        if (!scaled || norm < s.minValue || norm > s.maxValue || m.recipient == address(0)) {
            return (false, TripReason.BOUNDS);
        }

        // 3. confidential policy (CRE): only an explicit DENY latches the breaker
        if (address(s.policy) != address(0)) {
            (uint8 verdict,) = s.policy.evaluate(mid, proof);
            if (verdict == POLICY_DENY) return (false, TripReason.POLICY);
            if (verdict != POLICY_ALLOW) return (false, TripReason.POLICY_HOLD);
        }

        if (s.seen[mid]) return (false, TripReason.REPLAY); // 4. replay
        if (m.appNonce != s.lastNonce[m.srcId] + 1) return (false, TripReason.NONCE_GAP); // 4. ordering

        if (s.rateCapacity != 0 && norm > _available(s)) return (false, TripReason.RATE_LIMIT); // 5. rate

        if (!_volumeOk(s, m, norm, mid, proof)) return (false, TripReason.VOLUME_SPIKE); // 6. volume

        return (true, TripReason.NONE);
    }

    /// @notice Commits replay, nonce, rate, and local-volume state for an approved settlement.
    /// @dev Must be called only after evaluate returns true. It does not call the external identity, policy, or volume contracts.
    /// @param s Guard storage to update.
    /// @param m Settlement whose acceptance is committed.
    function commit(GuardState storage s, SettlementMessage calldata m) external {
        (uint256 norm,) = _normalise(s, m);

        s.seen[digest(m)] = true;
        s.lastNonce[m.srcId] = m.appNonce;

        if (s.rateCapacity != 0) {
            s.tokens = _available(s) - norm; // _available is stable within the block
            s.lastRefill = block.timestamp;
        }

        if (address(s.volumeOracle) == address(0) && s.spikeFactorBps != 0) {
            VolumeStat storage v = s.volume[m.srcId];
            uint256 n = v.observations;
            if (n < s.warmup) {
                v.baseline = (v.baseline * n + norm) / (n + 1); // running mean during warmup
            } else {
                v.baseline = (v.baseline * (EMA_ALPHA - 1) + norm) / EMA_ALPHA;
            }
            v.observations = n + 1;
        }
    }

    /// @notice Calculates the token-bucket allowance available at the current timestamp.
    /// @param s Guard storage containing bucket state.
    /// @return Available normalized allowance capped at rateCapacity.
    function _available(GuardState storage s) private view returns (uint256) {
        uint256 refilled = s.tokens + (block.timestamp - s.lastRefill) * s.rateRefillPerSec;
        return refilled > s.rateCapacity ? s.rateCapacity : refilled; // capped at capacity
    }

    /// @notice Checks a settlement against the configured external or local volume policy.
    /// @dev An external oracle replaces local EMA checks. With neither oracle nor spike factor, volume checking is disabled.
    /// @param s Guard storage containing volume configuration and history.
    /// @param m Settlement whose source selects local history.
    /// @param norm Settlement value in 18-decimal-normalized units.
    /// @param mid Chain- and guard-bound settlement digest.
    /// @param proof Evidence passed to an external oracle, when configured.
    /// @return True when the configured volume policy permits the settlement.
    function _volumeOk(
        GuardState storage s,
        SettlementMessage calldata m,
        uint256 norm,
        bytes32 mid,
        bytes calldata proof
    ) private view returns (bool) {
        if (address(s.volumeOracle) != address(0)) {
            return s.volumeOracle.verify(mid, proof); // baseline stays private
        }
        if (s.spikeFactorBps == 0) return true;
        VolumeStat storage v = s.volume[m.srcId];
        if (v.baseline == 0 || v.observations < s.warmup) return true;
        return norm <= v.baseline * s.spikeFactorBps / BPS;
    }
}
