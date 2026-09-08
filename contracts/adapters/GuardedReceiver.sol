// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { PortcullisGuard } from "../core/PortcullisGuard.sol";
import { SettlementMessage } from "../core/types/GuardTypes.sol";

abstract contract GuardedReceiver {
    PortcullisGuard public immutable guard;

    event SettlementRejected(bytes32 indexed messageId);

    constructor(PortcullisGuard guard_) {
        guard = guard_;
    }

    function receiveMessage(bytes calldata wire) external {
        (SettlementMessage memory m, bytes memory proof) = _decode(wire);
        if (!guard.inspect(m, proof)) {
            emit SettlementRejected(m.messageId);
            return;
        }
        _handleValidated(m);
    }

    function _decode(bytes calldata wire) internal view virtual returns (SettlementMessage memory m, bytes memory proof);

    function _handleValidated(SettlementMessage memory m) internal virtual;
}
