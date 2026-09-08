// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

interface IPreSettlementPolicy {
    function evaluate(bytes32 msgHash, bytes calldata attestation) external view returns (uint8 verdict, uint8 riskMask);
}
