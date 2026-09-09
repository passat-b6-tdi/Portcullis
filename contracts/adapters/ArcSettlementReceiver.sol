// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { GuardedReceiver } from "./GuardedReceiver.sol";
import { PortcullisGuard } from "../core/PortcullisGuard.sol";
import { SettlementMessage } from "../core/types/GuardTypes.sol";

contract ArcSettlementReceiver is GuardedReceiver {
    using SafeERC20 for IERC20;

    event SettlementPaid(bytes32 indexed messageId, address indexed recipient, address token, uint256 value);

    constructor(PortcullisGuard guard_) GuardedReceiver(guard_) { }

    function _decode(bytes calldata wire)
        internal
        pure
        override
        returns (SettlementMessage memory m, bytes memory proof)
    {
        (m, proof) = abi.decode(wire, (SettlementMessage, bytes));
    }

    function _handleValidated(SettlementMessage memory m) internal override {
        IERC20(m.token).safeTransfer(m.recipient, m.value);
        emit SettlementPaid(m.messageId, m.recipient, m.token, m.value);
    }
}
