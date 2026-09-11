// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

/// @title Interface for an external volume verdict provider.
interface IVolumeVerdictOracle {
    /// @notice Verifies whether a settlement passes an external volume policy.
    /// @param msgHash Chain- and guard-bound digest of the settlement message.
    /// @param proof Oracle-specific off-chain evidence, such as a TEE signature.
    /// @return ok True only when the oracle permits the settlement.
    function verify(bytes32 msgHash, bytes calldata proof) external view returns (bool ok);
}
