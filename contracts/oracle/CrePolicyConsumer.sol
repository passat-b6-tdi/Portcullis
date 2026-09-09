// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { ECDSA } from "solady/utils/ECDSA.sol";
import { IPreSettlementPolicy } from "../core/interfaces/IPreSettlementPolicy.sol";
import { AddressHelper } from "../AddressHelper.sol";

contract CrePolicyConsumer is IPreSettlementPolicy {
    using AddressHelper for address;
    error ZeroSigner();

    uint8 internal constant DENY = 2;
    uint256 public constant MAX_AGE = 10 minutes;

    address public immutable signer;

    constructor(address signer_) {
        signer_.zeroAddressCheck();
        signer = signer_;
    }

    function evaluate(bytes32 msgHash, bytes calldata attestation)
        external
        view
        returns (uint8 verdict, uint8 riskMask)
    {
        if (attestation.length == 0) return (DENY, 0);

        uint64 issuedAt;
        bytes memory sig;
        (verdict, riskMask, issuedAt, sig) = abi.decode(attestation, (uint8, uint8, uint64, bytes));

        if (block.timestamp > uint256(issuedAt) + MAX_AGE) return (DENY, riskMask);

        bytes32 digest = ECDSA.toEthSignedMessageHash(keccak256(abi.encode(msgHash, verdict, riskMask, issuedAt)));
        if (ECDSA.tryRecover(digest, sig) != signer) return (DENY, riskMask);
    }
}
