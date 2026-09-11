// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

/// @title Source authority resolver used by PortcullisGuard.
interface IIdentityRegistry {
    /// @notice Resolves a source identifier to the address authorized to sign its messages.
    /// @dev Implementations return address(0) for unknown or unresolvable sources; the guard fails closed.
    /// @param srcId Source identifier in a SettlementMessage.
    /// @return authority Signing authority, or address(0) when the source cannot be resolved.
    function resolve(bytes32 srcId) external view returns (address authority);
}
