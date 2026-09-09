// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { ECDSA } from "solady/utils/ECDSA.sol";
import { SettlementMessage, GuardState, TripReason, VolumeStat } from "./types/GuardTypes.sol";
import { IIdentityRegistry } from "./interfaces/IIdentityRegistry.sol";

library PortcullisChecks {
    uint8 internal constant BIT_BINDING = 1 << 0;
    uint8 internal constant BIT_BOUNDS = 1 << 1;
    uint8 internal constant BIT_REPLAY = 1 << 2;
    uint8 internal constant BIT_RATE = 1 << 3;
    uint8 internal constant BIT_VOLUME = 1 << 4;
    uint8 internal constant BIT_POLICY = 1 << 5;

    uint8 internal constant PASS_MASK = BIT_BINDING | BIT_BOUNDS | BIT_REPLAY | BIT_RATE | BIT_VOLUME | BIT_POLICY;

    // CRE verdict codes: 1 ALLOW, 2 DENY, 3 REVIEW, 0 none
    uint8 internal constant POLICY_ALLOW = 1;
    uint8 internal constant POLICY_DENY = 2;

    uint256 private constant BPS = 10_000;
    uint256 private constant EMA_ALPHA = 8;

    function digest(SettlementMessage calldata m) internal view returns (bytes32) {
        return keccak256(abi.encode(block.chainid, address(this), m));
    }

    function _normalise(GuardState storage s, SettlementMessage calldata m)
        private
        view
        returns (uint256 norm, bool ok)
    {
        uint256 scale = s.tokenScale[m.token];
        if (scale == 0 || m.value > type(uint256).max / scale) return (0, false);
        return (m.value * scale, true);
    }

    // view-only: runs all detectors in order, never writes
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

    function _available(GuardState storage s) private view returns (uint256) {
        uint256 refilled = s.tokens + (block.timestamp - s.lastRefill) * s.rateRefillPerSec;
        return refilled > s.rateCapacity ? s.rateCapacity : refilled; // capped at capacity
    }

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
