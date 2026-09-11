// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { GuardedReceiver } from "./GuardedReceiver.sol";
import { PortcullisGuard } from "../core/PortcullisGuard.sol";
import { SettlementMessage } from "../core/types/GuardTypes.sol";

/// @title Guarded receiver that settles approved ERC-20 messages with a direct token transfer.
contract ArcSettlementReceiver is GuardedReceiver {
    using SafeTransferLib for address;

    /// @notice Emitted after an approved settlement token transfer succeeds.
    /// @param messageId Digest of the paid settlement.
    /// @param recipient Recipient of the transferred tokens.
    /// @param token ERC-20 token transferred from this receiver.
    /// @param value Token-native amount transferred.
    event SettlementPaid(bytes32 indexed messageId, address indexed recipient, address token, uint256 value);

    /// @notice Initializes the receiver with its Portcullis guard.
    /// @dev The guard address is immutable through the inherited constructor.
    /// @param guard_ Guard that authorizes inbound settlement messages.
    constructor(PortcullisGuard guard_) GuardedReceiver(guard_) { }

    /// @inheritdoc GuardedReceiver
    /// @dev Decodes the wire as an ABI tuple of SettlementMessage and proof.
    function _decode(bytes calldata wire)
        internal
        pure
        override
        returns (SettlementMessage memory m, bytes memory proof)
    {
        (m, proof) = abi.decode(wire, (SettlementMessage, bytes));
    }

    /// @inheritdoc GuardedReceiver
    /// @dev Transfers the approved token only after the guard has committed acceptance state.
    function _handleValidated(SettlementMessage memory m) internal override {
        m.token.safeTransfer(m.recipient, m.value);
        emit SettlementPaid(guard.digestOf(m), m.recipient, m.token, m.value);
    }
}
