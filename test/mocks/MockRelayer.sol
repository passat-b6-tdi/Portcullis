// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { GuardedReceiver } from "../../contracts/adapters/GuardedReceiver.sol";
import { SettlementMessage } from "../../contracts/core/types/GuardTypes.sol";

contract MockRelayer {
    function send(GuardedReceiver to, SettlementMessage memory m, bytes memory proof) public {
        to.receiveMessage(abi.encode(m, proof));
    }

    function sendRaw(GuardedReceiver to, bytes calldata wire) external {
        to.receiveMessage(wire);
    }

    function replay(GuardedReceiver to, SettlementMessage memory m, uint256 newNonce) external {
        m.appNonce = newNonce;
        send(to, m, "");
    }

    function spoofSender(GuardedReceiver to, SettlementMessage memory m, address badSender) external {
        m.sender = badSender;
        send(to, m, "");
    }

    function oversized(GuardedReceiver to, SettlementMessage memory m, uint256 inflatedValue) external {
        m.value = inflatedValue;
        send(to, m, "");
    }
}
