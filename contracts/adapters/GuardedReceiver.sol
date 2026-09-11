// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { PortcullisGuard } from "../core/PortcullisGuard.sol";
import { SettlementMessage } from "../core/types/GuardTypes.sol";

/// @title Adapter base that passes decoded settlement messages through a PortcullisGuard.
/// @dev Subclasses define wire decoding and the post-validation settlement action.
abstract contract GuardedReceiver {
    /// @notice Emitted when the guard rejects a decoded settlement without reverting the adapter call.
    /// @param messageId Digest of the rejected settlement message.
    event SettlementRejected(bytes32 indexed messageId);

    /// @notice Guard that authorizes messages before this adapter handles them.
    PortcullisGuard public immutable guard;

    /// @notice Sets the guard used by this receiver.
    /// @dev The guard is immutable after construction.
    /// @param guard_ PortcullisGuard that must approve each decoded message.
    constructor(PortcullisGuard guard_) {
        guard = guard_;
    }

    /// @notice Decodes, inspects, and, if cleared, processes an inbound settlement wire payload.
    /// @dev A rejection emits SettlementRejected and returns successfully; only approved messages reach _handleValidated.
    /// @param wire Adapter-specific ABI-encoded message and proof.
    function receiveMessage(bytes calldata wire) external {
        (SettlementMessage memory m, bytes memory proof) = _decode(wire);
        if (!guard.inspect(m, proof)) {
            emit SettlementRejected(guard.digestOf(m));
            return;
        }
        _handleValidated(m);
    }

    /// @notice Decodes an adapter wire payload into a settlement message and proof.
    /// @param wire Adapter-specific inbound payload.
    /// @return m Decoded settlement message.
    /// @return proof Decoded authority signature or policy evidence.
    function _decode(bytes calldata wire) internal view virtual returns (SettlementMessage memory m, bytes memory proof);

    /// @notice Performs the adapter-specific action for a guard-approved settlement.
    /// @dev Called only after inspect has returned true and committed guard state.
    /// @param m Settlement that has passed inspection and whose guard state has been committed.
    function _handleValidated(SettlementMessage memory m) internal virtual;
}
