// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { SettlementMessage, GuardState, TripReason, VolumeStat } from "./types/GuardTypes.sol";
import { IIdentityRegistry } from "./interfaces/IIdentityRegistry.sol";
import { IVolumeVerdictOracle } from "./interfaces/IVolumeVerdictOracle.sol";
import { IPreSettlementPolicy } from "./interfaces/IPreSettlementPolicy.sol";
import { PortcullisChecks } from "./PortcullisChecks.sol";

import { AddressHelper } from "../AddressHelper.sol";

contract PortcullisGuard is OwnableRoles {
    using PortcullisChecks for GuardState;
    using AddressHelper for address;

    error Portcullis__Paused();
    error Portcullis__BadConfig();

    event SentinelTripped(TripReason reason, bytes32 indexed messageId, address indexed reporter);
    event SentinelCleared(address indexed guardian);

    event SettlementInspected(
        bytes32 indexed messageId,
        bytes32 indexed srcId,
        address recipient,
        address token,
        uint256 value,
        bool cleared,
        TripReason reason,
        uint8 detectorMask
    );
    event BoundsSet(uint256 minValue, uint256 maxValue);
    event TokenAllowed(address indexed token, bool allowed, uint8 decimals);
    event RateSet(uint256 capacity, uint256 refillPerSec);
    event VolumePolicySet(address indexed oracle, uint256 spikeFactorBps, uint256 warmup);
    event PolicySet(address indexed policy);
    event GuardianTransferred(address indexed from, address indexed to);
    event SourceEnrolled(bytes32 indexed srcId, bool enrolled);
    event AdapterSet(address indexed adapter, bool allowed);
    event SeenReset(bytes32 indexed messageId);
    event NonceResynced(bytes32 indexed srcId, uint256 nonce);

    uint256 public constant GUARDIAN_ROLE = 1 << 0;
    uint256 public constant ADAPTER_ROLE = 1 << 1;

    IIdentityRegistry public immutable identity;

    GuardState internal _s;

    constructor(address _owner, address guardian_, address identity_) {
        _owner.zeroAddressCheck();
        guardian_.zeroAddressCheck();
        identity_.zeroAddressCheck();
        _initializeOwner(_owner);
        _grantRoles(guardian_, GUARDIAN_ROLE);
        identity = IIdentityRegistry(identity_);
    }

    function inspect(SettlementMessage calldata m, bytes calldata proof)
        external
        onlyRoles(ADAPTER_ROLE)
        returns (bool)
    {
        GuardState storage s = _s;
        require(!s.paused, Portcullis__Paused());

        bytes32 mid = PortcullisChecks.digest(m);
        (bool ok, TripReason reason) = s.evaluate(m, identity, proof);
        if (!ok) {
            if (_latching(reason)) _trip(reason, mid);
            emit SettlementInspected(mid, m.srcId, m.recipient, m.token, m.value, false, reason, 0);
            return false;
        }

        s.commit(m);
        emit SettlementInspected(
            mid, m.srcId, m.recipient, m.token, m.value, true, TripReason.NONE, PortcullisChecks.PASS_MASK
        );
        return true;
    }

    function digestOf(SettlementMessage calldata m) external view returns (bytes32) {
        return PortcullisChecks.digest(m);
    }

    function clear() external onlyRoles(GUARDIAN_ROLE) {
        _s.paused = false;
        emit SentinelCleared(msg.sender);
    }

    function transferGuardian(address to) external onlyRoles(GUARDIAN_ROLE) {
        to.zeroAddressCheck();
        require(to != msg.sender, Portcullis__BadConfig());
        _grantRoles(to, GUARDIAN_ROLE);
        _removeRoles(msg.sender, GUARDIAN_ROLE);
        emit GuardianTransferred(msg.sender, to);
    }

    function renounceOwnership() public payable override onlyOwner {
        revert Portcullis__BadConfig();
    }

    function setEnrolled(bytes32 srcId, bool value) external onlyRoles(GUARDIAN_ROLE) {
        _s.enrolled[srcId] = value;
        emit SourceEnrolled(srcId, value);
    }

    function setAdapter(address adapter, bool allowed) external onlyRoles(GUARDIAN_ROLE) {
        adapter.zeroAddressCheck();
        if (allowed) _grantRoles(adapter, ADAPTER_ROLE);
        else _removeRoles(adapter, ADAPTER_ROLE);
        emit AdapterSet(adapter, allowed);
    }

    function resetSeen(bytes32 messageId) external onlyRoles(GUARDIAN_ROLE) {
        delete _s.seen[messageId];
        emit SeenReset(messageId);
    }

    function resyncNonce(bytes32 srcId, uint256 nonce) external onlyRoles(GUARDIAN_ROLE) {
        _s.lastNonce[srcId] = nonce;
        emit NonceResynced(srcId, nonce);
    }

    function setBounds(uint256 minValue, uint256 maxValue) external onlyRoles(GUARDIAN_ROLE) {
        require(minValue < maxValue, Portcullis__BadConfig());
        _s.minValue = minValue;
        _s.maxValue = maxValue;
        emit BoundsSet(minValue, maxValue);
    }

    function setAllowedToken(address token, bool allowed, uint8 decimals) external onlyRoles(GUARDIAN_ROLE) {
        require(decimals <= 18, Portcullis__BadConfig());
        _s.tokenScale[token] = allowed ? 10 ** (18 - uint256(decimals)) : 0;
        emit TokenAllowed(token, allowed, decimals);
    }

    function setRate(uint256 capacity, uint256 refillPerSec) external onlyRoles(GUARDIAN_ROLE) {
        _s.rateCapacity = capacity;
        _s.rateRefillPerSec = refillPerSec;
        _s.tokens = capacity;
        _s.lastRefill = block.timestamp;
        emit RateSet(capacity, refillPerSec);
    }

    function setVolumePolicy(IVolumeVerdictOracle oracle, uint256 spikeFactorBps, uint256 warmup)
        external
        onlyRoles(GUARDIAN_ROLE)
    {
        _s.volumeOracle = oracle;
        _s.spikeFactorBps = spikeFactorBps;
        _s.warmup = warmup;
        emit VolumePolicySet(address(oracle), spikeFactorBps, warmup);
    }

    function setPolicy(IPreSettlementPolicy policy_) external onlyRoles(GUARDIAN_ROLE) {
        _s.policy = policy_;
        emit PolicySet(address(policy_));
    }

    function isGuardian(address account) external view returns (bool) {
        return hasAnyRole(account, GUARDIAN_ROLE);
    }

    function isAdapter(address account) external view returns (bool) {
        return hasAnyRole(account, ADAPTER_ROLE);
    }

    function enrolled(bytes32 srcId) external view returns (bool) {
        return _s.enrolled[srcId];
    }

    function paused() external view returns (bool) {
        return _s.paused;
    }

    function bounds() external view returns (uint256 minValue, uint256 maxValue) {
        return (_s.minValue, _s.maxValue);
    }

    function allowedToken(address token) external view returns (bool) {
        return _s.tokenScale[token] != 0;
    }

    function tokenScale(address token) external view returns (uint256) {
        return _s.tokenScale[token];
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

    function volumeState() external view returns (address oracle, uint256 spikeFactorBps, uint256 warmup) {
        return (address(_s.volumeOracle), _s.spikeFactorBps, _s.warmup);
    }

    function volumeStatOf(bytes32 srcId) external view returns (uint256 baseline, uint256 observations) {
        VolumeStat storage v = _s.volume[srcId];
        return (v.baseline, v.observations);
    }

    function _latching(TripReason reason) private pure returns (bool) {
        return reason == TripReason.RATE_LIMIT || reason == TripReason.VOLUME_SPIKE || reason == TripReason.POLICY;
    }

    function _trip(TripReason reason, bytes32 messageId) internal {
        _s.paused = true;
        emit SentinelTripped(reason, messageId, msg.sender);
    }
}
