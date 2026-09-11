// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Ownable } from "solady/auth/Ownable.sol";
import { ReceiverTemplate } from "./ReceiverTemplate.sol";
import { IPreSettlementPolicy } from "../core/interfaces/IPreSettlementPolicy.sol";
import { AddressHelper } from "../AddressHelper.sol";

/// @title Chainlink CRE report consumer that exposes time-limited policy verdicts to PortcullisGuard.
/// @dev A missing or stale report is not ALLOW, so a connected guard holds the settlement closed.
contract CrePolicyConsumer is ReceiverTemplate, Ownable, IPreSettlementPolicy {
    using AddressHelper for address;

    /// @notice Emitted after an authenticated CRE report replaces a settlement verdict.
    /// @param msgHash Digest to which the verdict applies.
    /// @param code CRE verdict code: 1 ALLOW, 2 DENY, 3 MANUAL_REVIEW, or 0 none.
    /// @param riskMask Bitmask of policy risk reasons.
    /// @param issuedAt Unix timestamp embedded in the report.
    event VerdictStored(bytes32 indexed msgHash, uint8 code, uint8 riskMask, uint64 issuedAt);
    /// @notice Emitted when the maximum accepted report age changes.
    /// @param maxAge Maximum report age in seconds.
    event MaxAgeSet(uint256 maxAge);
    /// @notice Emitted when the authorized CRE report forwarder changes.
    /// @param forwarder New forwarder address.
    event ForwarderSet(address forwarder);

    /// @title Policy result stored from a CRE report.
    struct Verdict {
        /// @notice CRE verdict code.
        uint8 code;
        /// @notice CRE risk-reason bitmask.
        uint8 riskMask;
        /// @notice Unix timestamp at which CRE issued the verdict.
        uint64 issuedAt;
    }

    /// @notice Verdict returned when no report has been stored for a digest.
    uint8 internal constant UNKNOWN = 0;
    /// @notice Verdict returned for a report older than maxAge, surfaced as MANUAL_REVIEW.
    uint8 internal constant STALE = 3;

    /// @notice Maximum age in seconds for a stored report to remain usable.
    uint256 public maxAge = 1 hours;
    /// @notice Stored CRE verdicts keyed by chain- and guard-bound settlement digest.
    mapping(bytes32 => Verdict) internal _verdict;

    /// @notice Initializes the CRE report forwarder and owner.
    /// @param forwarder_ Nonzero address authorized to deliver CRE reports.
    /// @param owner_ Account permitted to administer report age and forwarder configuration.
    constructor(address forwarder_, address owner_) ReceiverTemplate(forwarder_) {
        owner_.zeroAddressCheck();
        _initializeOwner(owner_);
    }

    /// @inheritdoc IPreSettlementPolicy
    /// @dev Ignores attestation because CRE pushes verdicts before inspection. Missing and stale entries intentionally do not return ALLOW.
    function evaluate(bytes32 msgHash, bytes calldata) external view returns (uint8 verdict, uint8 riskMask) {
        Verdict memory v = _verdict[msgHash];
        if (v.issuedAt == 0) return (UNKNOWN, 0);
        if (block.timestamp > uint256(v.issuedAt) + maxAge) return (STALE, v.riskMask);
        return (v.code, v.riskMask);
    }

    /// @notice Returns the raw stored CRE verdict for a settlement digest.
    /// @param msgHash Digest whose stored report is queried.
    /// @return code CRE verdict code.
    /// @return riskMask CRE risk-reason bitmask.
    /// @return issuedAt Unix timestamp embedded in the report.
    function verdictOf(bytes32 msgHash) external view returns (uint8 code, uint8 riskMask, uint64 issuedAt) {
        Verdict memory v = _verdict[msgHash];
        return (v.code, v.riskMask, v.issuedAt);
    }

    /// @notice Sets the period for which a CRE report remains valid.
    /// @param seconds_ New maximum report age in seconds; zero makes reports stale immediately after their issuance timestamp.
    function setMaxAge(uint256 seconds_) external onlyOwner {
        maxAge = seconds_;
        emit MaxAgeSet(seconds_);
    }

    /// @inheritdoc ReceiverTemplate
    /// @dev Reverts for a zero address and emits ForwarderSet after updating the receiver template's sender gate.
    function setForwarderAddress(address forwarder_) external override onlyOwner {
        forwarder_.zeroAddressCheck();
        _forwarder = forwarder_;
        emit ForwarderSet(forwarder_);
    }

    /// @notice Disables ownership renunciation so CRE consumer administration cannot be abandoned.
    /// @dev Always reverts with Ownable.Unauthorized.
    function renounceOwnership() public payable override onlyOwner {
        revert Unauthorized();
    }

    /// @inheritdoc ReceiverTemplate
    /// @dev Decodes report as (bytes32 msgHash, uint8 code, uint8 riskMask, uint64 issuedAt) and overwrites the prior verdict.
    function _processReport(bytes calldata report) internal override {
        (bytes32 msgHash, uint8 code, uint8 riskMask, uint64 issuedAt) =
            abi.decode(report, (bytes32, uint8, uint8, uint64));
        _verdict[msgHash] = Verdict(code, riskMask, issuedAt);
        emit VerdictStored(msgHash, code, riskMask, issuedAt);
    }
}
