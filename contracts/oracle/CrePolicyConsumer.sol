// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Ownable } from "solady/auth/Ownable.sol";
import { ReceiverTemplate } from "./ReceiverTemplate.sol";
import { IPreSettlementPolicy } from "../core/interfaces/IPreSettlementPolicy.sol";
import { AddressHelper } from "../AddressHelper.sol";

// Verdict codes match the CRE report: 1 = ALLOW, 2 = DENY, 3 = MANUAL_REVIEW; 0 = none.
contract CrePolicyConsumer is ReceiverTemplate, Ownable, IPreSettlementPolicy {
    using AddressHelper for address;

    event VerdictStored(bytes32 indexed msgHash, uint8 code, uint8 riskMask, uint64 issuedAt);
    event MaxAgeSet(uint256 maxAge);
    event ForwarderSet(address forwarder);

    struct Verdict {
        uint8 code;
        uint8 riskMask;
        uint64 issuedAt;
    }

    uint8 internal constant DENY = 2;

    uint256 public maxAge = 1 hours;
    mapping(bytes32 => Verdict) internal _verdict;

    constructor(address forwarder_, address owner_) ReceiverTemplate(forwarder_) {
        owner_.zeroAddressCheck();
        _initializeOwner(owner_);
    }

    function evaluate(bytes32 msgHash, bytes calldata) external view returns (uint8 verdict, uint8 riskMask) {
        Verdict memory v = _verdict[msgHash];
        if (v.issuedAt == 0) return (DENY, 0);
        if (block.timestamp > uint256(v.issuedAt) + maxAge) return (DENY, v.riskMask);
        return (v.code, v.riskMask);
    }

    function verdictOf(bytes32 msgHash) external view returns (uint8 code, uint8 riskMask, uint64 issuedAt) {
        Verdict memory v = _verdict[msgHash];
        return (v.code, v.riskMask, v.issuedAt);
    }

    function setMaxAge(uint256 seconds_) external onlyOwner {
        maxAge = seconds_;
        emit MaxAgeSet(seconds_);
    }

    function setForwarderAddress(address forwarder_) external override onlyOwner {
        forwarder_.zeroAddressCheck();
        _forwarder = forwarder_;
        emit ForwarderSet(forwarder_);
    }

    function renounceOwnership() public payable override onlyOwner {
        revert Unauthorized();
    }

    function _processReport(bytes calldata report) internal override {
        (bytes32 msgHash, uint8 code, uint8 riskMask, uint64 issuedAt) =
            abi.decode(report, (bytes32, uint8, uint8, uint64));
        _verdict[msgHash] = Verdict(code, riskMask, issuedAt);
        emit VerdictStored(msgHash, code, riskMask, issuedAt);
    }
}
