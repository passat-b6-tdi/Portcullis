// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

interface IVolumeVerdictOracle {
    // msgHash = keccak256(abi.encode(message)); proof = off-chain (TEE) signature
    function verify(bytes32 msgHash, bytes calldata proof) external view returns (bool ok);
}
