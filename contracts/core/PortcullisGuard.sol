// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { SettlementMessage, GuardState, TripReason, VolumeStat } from "./types/GuardTypes.sol";
import { IIdentityRegistry } from "./interfaces/IIdentityRegistry.sol";
import { IVolumeVerdictOracle } from "./interfaces/IVolumeVerdictOracle.sol";
import { IPreSettlementPolicy } from "./interfaces/IPreSettlementPolicy.sol";
import { PortcullisChecks } from "./PortcullisChecks.sol";

import { AddressHelper } from "../AddressHelper.sol";

/// @title Configurable firewall for inbound cross-chain settlement messages.
/// @dev Adapters call inspect before releasing funds. Accepted messages commit state only after all delegated checks pass; authenticated rate, volume, and explicit-policy anomalies latch the guard.
contract PortcullisGuard is OwnableRoles {
    using PortcullisChecks for GuardState;
    using AddressHelper for address;

    /// @notice Raised when an adapter submits while the circuit breaker is latched.
    error Portcullis__Paused();
    /// @notice Raised when a guardian supplies an invalid configuration or attempts to renounce ownership.
    error Portcullis__BadConfig();

    /// @notice Emitted when an authenticated anomaly latches the circuit breaker.
    /// @param reason Detector that triggered the latch.
    /// @param messageId Digest of the triggering settlement.
    /// @param reporter Adapter that submitted the settlement.
    event SentinelTripped(TripReason reason, bytes32 indexed messageId, address indexed reporter);
    /// @notice Emitted when a guardian reopens the circuit breaker.
    /// @param guardian Guardian that cleared the latch.
    event SentinelCleared(address indexed guardian);

    /// @notice Records the result of each inspected settlement.
    /// @param messageId Chain- and guard-bound settlement digest.
    /// @param srcId Source identifier from the settlement.
    /// @param recipient Intended settlement beneficiary.
    /// @param token Token in which the settlement is denominated.
    /// @param value Token-native settlement amount.
    /// @param cleared Whether all checks passed and state was committed.
    /// @param reason First detector rejection reason, or NONE when cleared.
    /// @param detectorMask PASS_MASK when cleared, otherwise zero.
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
    /// @notice Emitted when inclusive normalized settlement bounds change.
    /// @param minValue New lower bound in 18-decimal-normalized units.
    /// @param maxValue New upper bound in 18-decimal-normalized units.
    event BoundsSet(uint256 minValue, uint256 maxValue);
    /// @notice Emitted when a token allowlist entry is changed.
    /// @param token Token whose entry changed.
    /// @param allowed Whether the token is allowed.
    /// @param decimals Token decimals used to derive the normalization scale.
    event TokenAllowed(address indexed token, bool allowed, uint8 decimals);
    /// @notice Emitted when token-bucket rate settings change and the bucket is reset.
    /// @param capacity New bucket capacity in 18-decimal-normalized units.
    /// @param refillPerSec New bucket refill rate per second in normalized units.
    event RateSet(uint256 capacity, uint256 refillPerSec);
    /// @notice Emitted when the volume detector configuration changes.
    /// @param oracle External volume oracle, or zero to use local EMA logic.
    /// @param spikeFactorBps Local spike threshold in basis points of baseline.
    /// @param warmup Accepted messages required before local spike enforcement.
    event VolumePolicySet(address indexed oracle, uint256 spikeFactorBps, uint256 warmup);
    /// @notice Emitted when the optional pre-settlement policy contract changes.
    /// @param policy Policy contract, or zero to disable policy evaluation.
    event PolicySet(address indexed policy);
    /// @notice Emitted when the current guardian transfers its guardian role.
    /// @param from Guardian that relinquished the role.
    /// @param to New guardian.
    event GuardianTransferred(address indexed from, address indexed to);
    /// @notice Emitted when a source enrollment changes.
    /// @param srcId Source identifier affected.
    /// @param enrolled Whether the source is enrolled.
    event SourceEnrolled(bytes32 indexed srcId, bool enrolled);
    /// @notice Emitted when an adapter role is granted or removed.
    /// @param adapter Adapter address affected.
    /// @param allowed Whether the adapter now has permission to inspect messages.
    event AdapterSet(address indexed adapter, bool allowed);
    /// @notice Emitted when replay state is cleared for a message digest.
    /// @param messageId Digest whose seen flag was reset.
    event SeenReset(bytes32 indexed messageId);
    /// @notice Emitted when a source's expected nonce is manually changed.
    /// @param srcId Source identifier affected.
    /// @param nonce New last accepted nonce.
    event NonceResynced(bytes32 indexed srcId, uint256 nonce);

    /// @notice Role allowed to administer guard configuration and clear the circuit breaker.
    uint256 public constant GUARDIAN_ROLE = 1 << 0;
    /// @notice Role allowed to submit settlements to inspect.
    uint256 public constant ADAPTER_ROLE = 1 << 1;

    /// @notice Registry used to resolve the signing authority for an enrolled source.
    IIdentityRegistry public immutable identity;

    /// @dev Guard state shared with PortcullisChecks during delegated execution.
    GuardState internal _s;

    /// @notice Initializes guard ownership, its first guardian, and the source identity registry.
    /// @param _owner Contract owner; ownership cannot later be renounced.
    /// @param guardian_ Initial guardian with configuration and clear authority.
    /// @param identity_ Nonzero source authority registry.
    constructor(address _owner, address guardian_, address identity_) {
        _owner.zeroAddressCheck();
        guardian_.zeroAddressCheck();
        identity_.zeroAddressCheck();
        _initializeOwner(_owner);
        _grantRoles(guardian_, GUARDIAN_ROLE);
        identity = IIdentityRegistry(identity_);
    }

    /// @notice Inspects a settlement submitted by an enrolled adapter and commits it when it clears.
    /// @dev Reverts while paused. Rejections return false rather than reverting; RATE_LIMIT, VOLUME_SPIKE, and explicit POLICY DENY also latch the breaker.
    /// @param m Proposed settlement message.
    /// @param proof Authority signature plus any policy or oracle evidence.
    /// @return True when the message passed all checks and its replay, nonce, rate, and local-volume state was committed.
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

    /// @notice Computes the digest used by this guard for a settlement.
    /// @param m Settlement message to hash.
    /// @return Chain- and guard-bound message digest.
    function digestOf(SettlementMessage calldata m) external view returns (bytes32) {
        return PortcullisChecks.digest(m);
    }

    /// @notice Clears the circuit breaker.
    /// @dev Does not undo any configuration or accepted-message state.
    function clear() external onlyRoles(GUARDIAN_ROLE) {
        _s.paused = false;
        emit SentinelCleared(msg.sender);
    }

    /// @notice Transfers the caller's guardian role to a nonzero new guardian.
    /// @dev Reverts for the caller's own address. Other guardians, if any, retain their roles.
    /// @param to Recipient of the caller's guardian role.
    function transferGuardian(address to) external onlyRoles(GUARDIAN_ROLE) {
        to.zeroAddressCheck();
        require(to != msg.sender, Portcullis__BadConfig());
        _grantRoles(to, GUARDIAN_ROLE);
        _removeRoles(msg.sender, GUARDIAN_ROLE);
        emit GuardianTransferred(msg.sender, to);
    }

    /// @notice Prevents ownership renunciation.
    /// @dev Always reverts with Portcullis__BadConfig.
    function renounceOwnership() public payable override onlyOwner {
        revert Portcullis__BadConfig();
    }

    /// @notice Enrolls or removes a source identifier.
    /// @param srcId Source identifier to update.
    /// @param value Whether the source may pass the binding detector.
    function setEnrolled(bytes32 srcId, bool value) external onlyRoles(GUARDIAN_ROLE) {
        _s.enrolled[srcId] = value;
        emit SourceEnrolled(srcId, value);
    }

    /// @notice Grants or removes permission for an adapter to call inspect.
    /// @param adapter Nonzero adapter address.
    /// @param allowed Whether to grant the adapter role.
    function setAdapter(address adapter, bool allowed) external onlyRoles(GUARDIAN_ROLE) {
        adapter.zeroAddressCheck();
        if (allowed) _grantRoles(adapter, ADAPTER_ROLE);
        else _removeRoles(adapter, ADAPTER_ROLE);
        emit AdapterSet(adapter, allowed);
    }

    /// @notice Clears the replay marker for a message digest.
    /// @dev This does not change the source nonce; a resync may also be required before replaying a message.
    /// @param messageId Digest whose consumed state is removed.
    function resetSeen(bytes32 messageId) external onlyRoles(GUARDIAN_ROLE) {
        delete _s.seen[messageId];
        emit SeenReset(messageId);
    }

    /// @notice Sets the last accepted nonce for a source.
    /// @param srcId Source identifier to resynchronize.
    /// @param nonce New last accepted nonce, so the next accepted message must use nonce + 1.
    function resyncNonce(bytes32 srcId, uint256 nonce) external onlyRoles(GUARDIAN_ROLE) {
        _s.lastNonce[srcId] = nonce;
        emit NonceResynced(srcId, nonce);
    }

    /// @notice Sets inclusive settlement bounds in 18-decimal-normalized units.
    /// @dev Reverts unless minValue is strictly less than maxValue.
    /// @param minValue New lower bound.
    /// @param maxValue New upper bound.
    function setBounds(uint256 minValue, uint256 maxValue) external onlyRoles(GUARDIAN_ROLE) {
        require(minValue < maxValue, Portcullis__BadConfig());
        _s.minValue = minValue;
        _s.maxValue = maxValue;
        emit BoundsSet(minValue, maxValue);
    }

    /// @notice Allows or disallows a token and records its decimal normalization scale.
    /// @dev Reverts when decimals exceeds 18. Disallowing a token stores a zero scale.
    /// @param token Token whose entry is changed; zero is technically storable but cannot pass bounds as a usable ERC-20 settlement asset.
    /// @param allowed Whether the token is allowed.
    /// @param decimals Token decimal count used to normalize values.
    function setAllowedToken(address token, bool allowed, uint8 decimals) external onlyRoles(GUARDIAN_ROLE) {
        require(decimals <= 18, Portcullis__BadConfig());
        _s.tokenScale[token] = allowed ? 10 ** (18 - uint256(decimals)) : 0;
        emit TokenAllowed(token, allowed, decimals);
    }

    /// @notice Configures and resets the normalized token-bucket rate limiter.
    /// @dev A capacity of zero disables rate enforcement. Setting either value resets tokens to capacity and lastRefill to now.
    /// @param capacity Bucket capacity.
    /// @param refillPerSec Tokens refilled per second.
    function setRate(uint256 capacity, uint256 refillPerSec) external onlyRoles(GUARDIAN_ROLE) {
        _s.rateCapacity = capacity;
        _s.rateRefillPerSec = refillPerSec;
        _s.tokens = capacity;
        _s.lastRefill = block.timestamp;
        emit RateSet(capacity, refillPerSec);
    }

    /// @notice Configures external or local volume-spike detection.
    /// @dev A nonzero oracle fully replaces local EMA checks. With no oracle and zero spikeFactorBps, volume checking is disabled.
    /// @param oracle External verdict oracle, or zero for local EMA mode.
    /// @param spikeFactorBps Local threshold in basis points of baseline.
    /// @param warmup Required observations before local enforcement.
    function setVolumePolicy(IVolumeVerdictOracle oracle, uint256 spikeFactorBps, uint256 warmup)
        external
        onlyRoles(GUARDIAN_ROLE)
    {
        _s.volumeOracle = oracle;
        _s.spikeFactorBps = spikeFactorBps;
        _s.warmup = warmup;
        emit VolumePolicySet(address(oracle), spikeFactorBps, warmup);
    }

    /// @notice Sets the optional pre-settlement policy contract.
    /// @dev A zero address disables policy evaluation; a configured policy must return explicit ALLOW for a message to clear.
    /// @param policy_ Policy contract to query.
    function setPolicy(IPreSettlementPolicy policy_) external onlyRoles(GUARDIAN_ROLE) {
        _s.policy = policy_;
        emit PolicySet(address(policy_));
    }

    /// @notice Checks whether an account has the guardian role.
    /// @param account Account to query.
    /// @return True when account is a guardian.
    function isGuardian(address account) external view returns (bool) {
        return hasAnyRole(account, GUARDIAN_ROLE);
    }

    /// @notice Checks whether an account has the adapter role.
    /// @param account Account to query.
    /// @return True when account may call inspect.
    function isAdapter(address account) external view returns (bool) {
        return hasAnyRole(account, ADAPTER_ROLE);
    }

    /// @notice Returns whether a source identifier is enrolled.
    /// @param srcId Source identifier to query.
    /// @return True when the source is enrolled.
    function enrolled(bytes32 srcId) external view returns (bool) {
        return _s.enrolled[srcId];
    }

    /// @notice Returns whether the circuit breaker is latched.
    /// @return True while inspect reverts with Portcullis__Paused.
    function paused() external view returns (bool) {
        return _s.paused;
    }

    /// @notice Returns inclusive normalized settlement bounds.
    /// @return minValue Lower bound in 18-decimal-normalized units.
    /// @return maxValue Upper bound in 18-decimal-normalized units.
    function bounds() external view returns (uint256 minValue, uint256 maxValue) {
        return (_s.minValue, _s.maxValue);
    }

    /// @notice Returns whether a token has a nonzero normalization scale.
    /// @param token Token to query.
    /// @return True when the token is allowed.
    function allowedToken(address token) external view returns (bool) {
        return _s.tokenScale[token] != 0;
    }

    /// @notice Returns a token's multiplier for conversion to 18-decimal-normalized units.
    /// @param token Token to query.
    /// @return Scale, or zero when the token is not allowed.
    function tokenScale(address token) external view returns (uint256) {
        return _s.tokenScale[token];
    }

    /// @notice Returns whether a message digest has already been accepted.
    /// @param messageId Digest to query.
    /// @return True when the digest is marked consumed.
    function seen(bytes32 messageId) external view returns (bool) {
        return _s.seen[messageId];
    }

    /// @notice Returns a source's last accepted application nonce.
    /// @param srcId Source identifier to query.
    /// @return Last accepted nonce.
    function lastNonce(bytes32 srcId) external view returns (uint256) {
        return _s.lastNonce[srcId];
    }

    /// @notice Returns the current token-bucket configuration and stored state.
    /// @return capacity Bucket capacity.
    /// @return refillPerSec Bucket refill rate per second.
    /// @return tokens Unrefilled allowance stored at lastRefill.
    /// @return lastRefill Timestamp used as the bucket refill origin.
    function rateState()
        external
        view
        returns (uint256 capacity, uint256 refillPerSec, uint256 tokens, uint256 lastRefill)
    {
        return (_s.rateCapacity, _s.rateRefillPerSec, _s.tokens, _s.lastRefill);
    }

    /// @notice Returns the volume detector configuration.
    /// @return oracle External oracle address, or zero for local EMA mode.
    /// @return spikeFactorBps Local spike threshold in basis points.
    /// @return warmup Observations required before local spike enforcement.
    function volumeState() external view returns (address oracle, uint256 spikeFactorBps, uint256 warmup) {
        return (address(_s.volumeOracle), _s.spikeFactorBps, _s.warmup);
    }

    /// @notice Returns the local volume history for a source.
    /// @param srcId Source identifier to query.
    /// @return baseline Current normalized running mean or EMA.
    /// @return observations Number of accepted messages in the history.
    function volumeStatOf(bytes32 srcId) external view returns (uint256 baseline, uint256 observations) {
        VolumeStat storage v = _s.volume[srcId];
        return (v.baseline, v.observations);
    }

    /// @notice Identifies rejection reasons that should latch the circuit breaker.
    /// @param reason Settlement rejection reason.
    /// @return True for rate-limit, volume-spike, and explicit-policy denial.
    function _latching(TripReason reason) private pure returns (bool) {
        return reason == TripReason.RATE_LIMIT || reason == TripReason.VOLUME_SPIKE || reason == TripReason.POLICY;
    }

    /// @notice Latches the circuit breaker and records its triggering settlement.
    /// @param reason Authenticated anomaly that caused the latch.
    /// @param messageId Digest of the triggering settlement.
    function _trip(TripReason reason, bytes32 messageId) internal {
        _s.paused = true;
        emit SentinelTripped(reason, messageId, msg.sender);
    }
}
