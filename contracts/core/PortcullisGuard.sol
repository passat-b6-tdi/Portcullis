// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { SettlementMessage, GuardState, TripReason } from "./types/GuardTypes.sol";
import { IIdentityRegistry } from "./interfaces/IIdentityRegistry.sol";
import { IVolumeVerdictOracle } from "./interfaces/IVolumeVerdictOracle.sol";
import { IPreSettlementPolicy } from "./interfaces/IPreSettlementPolicy.sol";
import { PortcullisChecks } from "./PortcullisChecks.sol";

contract PortcullisGuard is OwnableRoles {
    using PortcullisChecks for GuardState;

    error Portcullis__Paused();
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
    event GuardianTransferred(address indexed from, address indexed to);

    // owner administers guardians; guardians operate the breaker
    uint256 public constant GUARDIAN_ROLE = 1 << 0;

    IIdentityRegistry public immutable identity;

    GuardState internal _s;

    constructor(address _owner, address guardian_, IIdentityRegistry identity_) {
        require(guardian_ != address(0), Portcullis__ZeroAddress());
        require(address(identity_) != address(0), Portcullis__ZeroAddress());
        _initializeOwner(_owner);
        _grantRoles(guardian_, GUARDIAN_ROLE);
        identity = identity_;
    }

    function inspect(SettlementMessage calldata m, bytes calldata proof) external returns (bool) {
        GuardState storage s = _s;
        require(!s.paused, Portcullis__Paused());

        (bool ok, TripReason reason) = s.evaluate(m, identity, proof);
        if (!ok) {
            _trip(reason, m.messageId);
            return false;
        }

        s.commit(m);
        emit SettlementCleared(m.messageId, PortcullisChecks.PASS_MASK);
        return true;
    }

    function clear() external onlyRoles(GUARDIAN_ROLE) {
        _s.paused = false;
        emit SentinelCleared(msg.sender);
    }

    function transferGuardian(address to) external onlyRoles(GUARDIAN_ROLE) {
        require(to != address(0), Portcullis__ZeroAddress());
        _grantRoles(to, GUARDIAN_ROLE);
        _removeRoles(msg.sender, GUARDIAN_ROLE);
        emit GuardianTransferred(msg.sender, to);
    }

    function renounceOwnership() public payable override onlyOwner {
        revert Portcullis__BadConfig();
    }

    function setBounds(uint256 minValue, uint256 maxValue) external onlyRoles(GUARDIAN_ROLE) {
        require(minValue < maxValue, Portcullis__BadConfig());
        _s.minValue = minValue;
        _s.maxValue = maxValue;
        emit BoundsSet(minValue, maxValue);
    }

    function setAllowedToken(address token, bool allowed) external onlyRoles(GUARDIAN_ROLE) {
        _s.allowedToken[token] = allowed;
        emit TokenAllowed(token, allowed);
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

    function paused() external view returns (bool) {
        return _s.paused;
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

    function _trip(TripReason reason, bytes32 messageId) internal {
        _s.paused = true;
        emit SentinelTripped(reason, messageId, msg.sender);
    }
}
