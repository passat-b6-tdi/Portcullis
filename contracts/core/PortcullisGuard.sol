// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { SettlementMessage, GuardState, TripReason } from "./types/GuardTypes.sol";
import { IIdentityRegistry } from "./interfaces/IIdentityRegistry.sol";
import { IVolumeVerdictOracle } from "./interfaces/IVolumeVerdictOracle.sol";
import { IPreSettlementPolicy } from "./interfaces/IPreSettlementPolicy.sol";
import { PortcullisChecks } from "./PortcullisChecks.sol";

contract PortcullisGuard {
    using PortcullisChecks for GuardState;

    error Portcullis__Paused();
    error Portcullis__NotGuardian();
    error Portcullis__ZeroAddress();
    error Portcullis__BadConfig();

    event SentinelTripped(TripReason reason, bytes32 indexed messageId, address indexed reporter);
    event SentinelCleared(address indexed guardian);
    event SettlementCleared(bytes32 indexed messageId, uint8 detectorMask);
    event BoundsSet(uint256 minValue, uint256 maxValue);
    event TokenAllowed(address indexed token, bool allowed);
    event RateSet(uint256 capacity, uint256 refillPerSec);
    event VolumePolicySet(address indexed oracle, uint256 spikeFactorBps, uint256 warmup);
    event PolicySet(address indexed policy);

    IIdentityRegistry public immutable identity;

    GuardState internal _s;

    modifier onlyGuardian() {
        if (msg.sender != _s.guardian) revert Portcullis__NotGuardian();
        _;
    }

    constructor(address guardian_, IIdentityRegistry identity_) {
        if (guardian_ == address(0) || address(identity_) == address(0)) revert Portcullis__ZeroAddress();
        _s.guardian = guardian_;
        identity = identity_;
    }

    function inspect(SettlementMessage calldata m, bytes calldata proof) external returns (bool) {
        GuardState storage s = _s;
        if (s.paused) revert Portcullis__Paused();

        (bool ok, TripReason reason) = s.evaluate(m, identity, proof);
        if (!ok) {
            _trip(reason, m.messageId);
            return false;
        }

        s.commit(m);
        emit SettlementCleared(m.messageId, PortcullisChecks.PASS_MASK);
        return true;
    }

    function clear() external onlyGuardian {
        _s.paused = false;
        emit SentinelCleared(msg.sender);
    }

    function setBounds(uint256 minValue, uint256 maxValue) external onlyGuardian {
        if (minValue > maxValue) revert Portcullis__BadConfig();
        _s.minValue = minValue;
        _s.maxValue = maxValue;
        emit BoundsSet(minValue, maxValue);
    }

    function setAllowedToken(address token, bool allowed) external onlyGuardian {
        _s.allowedToken[token] = allowed;
        emit TokenAllowed(token, allowed);
    }

    function setRate(uint256 capacity, uint256 refillPerSec) external onlyGuardian {
        _s.rateCapacity = capacity;
        _s.rateRefillPerSec = refillPerSec;
        _s.tokens = capacity;
        _s.lastRefill = block.timestamp;
        emit RateSet(capacity, refillPerSec);
    }

    function setVolumePolicy(IVolumeVerdictOracle oracle, uint256 spikeFactorBps, uint256 warmup)
        external
        onlyGuardian
    {
        _s.volumeOracle = oracle;
        _s.spikeFactorBps = spikeFactorBps;
        _s.warmup = warmup;
        emit VolumePolicySet(address(oracle), spikeFactorBps, warmup);
    }

    function setPolicy(IPreSettlementPolicy policy_) external onlyGuardian {
        _s.policy = policy_;
        emit PolicySet(address(policy_));
    }

    function _trip(TripReason reason, bytes32 messageId) internal {
        _s.paused = true;
        emit SentinelTripped(reason, messageId, msg.sender);
    }

    function paused() external view returns (bool) {
        return _s.paused;
    }

    function guardian() external view returns (address) {
        return _s.guardian;
    }

    function bounds() external view returns (uint256 minValue, uint256 maxValue) {
        return (_s.minValue, _s.maxValue);
    }

    function allowedToken(address token) external view returns (bool) {
        return _s.allowedToken[token];
    }

    function seen(bytes32 messageId) external view returns (bool) {
        return _s.seen[messageId];
    }

    function lastNonce(bytes32 srcId) external view returns (uint256) {
        return _s.lastNonce[srcId];
    }

    function rateState()
        external
        view
        returns (uint256 capacity, uint256 refillPerSec, uint256 tokens, uint256 lastRefill)
    {
        return (_s.rateCapacity, _s.rateRefillPerSec, _s.tokens, _s.lastRefill);
    }

    function volumeState()
        external
        view
        returns (address oracle, uint256 baseline, uint256 spikeFactorBps, uint256 observations, uint256 warmup)
    {
        return (address(_s.volumeOracle), _s.baseline, _s.spikeFactorBps, _s.observations, _s.warmup);
    }
}
