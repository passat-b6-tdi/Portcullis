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
}
