// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

/// @title Interface for a confidential or external policy verdict keyed by a settlement digest.
interface IPreSettlementPolicy {
    /// @notice Returns the current policy verdict and risk flags for a settlement digest.
    /// @param msgHash Chain- and guard-bound digest of the settlement message.
    /// @param attestation Policy-specific evidence supplied with the settlement.
    /// @return verdict Policy code, where Portcullis accepts only explicit ALLOW.
    /// @return riskMask Bitmask describing policy risk reasons.
    function evaluate(bytes32 msgHash, bytes calldata attestation) external view returns (uint8 verdict, uint8 riskMask);
}
