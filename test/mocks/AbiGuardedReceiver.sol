// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { GuardedReceiver } from "../../contracts/adapters/GuardedReceiver.sol";
import { PortcullisGuard } from "../../contracts/core/PortcullisGuard.sol";
import { SettlementMessage } from "../../contracts/core/types/GuardTypes.sol";

contract AbiGuardedReceiver is GuardedReceiver {
    mapping(address => uint256) public credited;
    uint256 public validatedCount;

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
        credited[m.recipient] += m.value;
        validatedCount++;
    }
}
