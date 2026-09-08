// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { SettlementMessage, GuardState, TripReason } from "./types/GuardTypes.sol";
import { IIdentityRegistry } from "./interfaces/IIdentityRegistry.sol";

library PortcullisChecks {
    uint8 internal constant BIT_BINDING = 1 << 0;
    uint8 internal constant BIT_BOUNDS = 1 << 1;
    uint8 internal constant BIT_REPLAY = 1 << 2;
    uint8 internal constant BIT_RATE = 1 << 3;
    uint8 internal constant BIT_VOLUME = 1 << 4;

    uint8 internal constant PASS_MASK = BIT_BINDING | BIT_BOUNDS | BIT_REPLAY | BIT_RATE | BIT_VOLUME;

    uint256 private constant BPS = 10_000;
    uint256 private constant EMA_ALPHA = 8; // baseline' = (7*baseline + value) / 8

    // view-only: runs all detectors in order, never writes
    function evaluate(
        GuardState storage s,
        SettlementMessage calldata m,
        IIdentityRegistry identity,
        bytes calldata proof
    ) internal view returns (bool ok, TripReason reason) {
        address authority = identity.resolve(m.srcId);
        if (m.sender == address(0) || authority == address(0) || authority != m.sender) {
            return (false, TripReason.BINDING); // 1. binding
        }

        if (m.value < s.minValue || m.value > s.maxValue || !s.allowedToken[m.token] || m.recipient == address(0)) {
            return (false, TripReason.BOUNDS); // 2. bounds
        }

        if (s.seen[m.messageId]) return (false, TripReason.REPLAY); // 3. replay
        if (m.appNonce != s.lastNonce[m.srcId] + 1) return (false, TripReason.NONCE_GAP); // 3. ordering

        if (s.rateCapacity != 0 && m.value > _available(s)) return (false, TripReason.RATE_LIMIT); // 4. rate

        if (!_volumeOk(s, m, proof)) return (false, TripReason.VOLUME_SPIKE); // 5. volume

        return (true, TripReason.NONE);
    }

    // called by the guard only after evaluate returns ok; no external calls
    function commit(GuardState storage s, SettlementMessage calldata m) internal {
        s.seen[m.messageId] = true;
        s.lastNonce[m.srcId] = m.appNonce;

        if (s.rateCapacity != 0) {
            s.tokens = _available(s) - m.value; // _available is stable within the block
            s.lastRefill = block.timestamp;
        }

        if (address(s.volumeOracle) == address(0) && s.spikeFactorBps != 0) {
            uint256 n = s.observations;
            if (n < s.warmup) {
                s.baseline = (s.baseline * n + m.value) / (n + 1); // running mean during warmup
            } else {
                s.baseline = (s.baseline * (EMA_ALPHA - 1) + m.value) / EMA_ALPHA;
            }
            s.observations = n + 1;
        }
    }

    function _available(GuardState storage s) private view returns (uint256) {
        uint256 refilled = s.tokens + (block.timestamp - s.lastRefill) * s.rateRefillPerSec;
        return refilled > s.rateCapacity ? s.rateCapacity : refilled; // capped at capacity
    }

    function _volumeOk(GuardState storage s, SettlementMessage calldata m, bytes calldata proof)
        private
        view
        returns (bool)
    {
        if (address(s.volumeOracle) != address(0)) {
            return s.volumeOracle.verify(keccak256(abi.encode(m)), proof); // baseline stays private
        }
        if (s.spikeFactorBps == 0 || s.baseline == 0 || s.observations < s.warmup) return true;
        return m.value <= s.baseline * s.spikeFactorBps / BPS;
    }
}
