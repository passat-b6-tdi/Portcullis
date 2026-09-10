// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Script, console2 } from "forge-std/Script.sol";
import { PortcullisGuard } from "../contracts/core/PortcullisGuard.sol";
import { ArcSettlementReceiver } from "../contracts/adapters/ArcSettlementReceiver.sol";

contract DeployArc is Script {
    function run() external returns (ArcSettlementReceiver receiver) {
        PortcullisGuard guard = PortcullisGuard(vm.envAddress("GUARD"));

        vm.startBroadcast();
        receiver = new ArcSettlementReceiver(guard);
        if (guard.isGuardian(msg.sender)) {
            guard.setAdapter(address(receiver), true);
        }
        vm.stopBroadcast();

        console2.log("ArcSettlementReceiver:", address(receiver));
        console2.log("guard:                ", address(guard));
        console2.log("registered as adapter:", guard.isAdapter(address(receiver)));
    }
}
