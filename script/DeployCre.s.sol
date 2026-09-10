// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Script, console2 } from "forge-std/Script.sol";
import { PortcullisGuard } from "../contracts/core/PortcullisGuard.sol";
import { CrePolicyConsumer } from "../contracts/oracle/CrePolicyConsumer.sol";

contract DeployCre is Script {
    function run() external returns (CrePolicyConsumer consumer) {
        PortcullisGuard guard = PortcullisGuard(vm.envAddress("GUARD"));
        address forwarder = vm.envAddress("CRE_FORWARDER");
        address owner = vm.envOr("CRE_OWNER", msg.sender);

        vm.startBroadcast();
        consumer = new CrePolicyConsumer(forwarder, owner);
        if (guard.isGuardian(msg.sender)) {
            guard.setPolicy(consumer);
        }
        vm.stopBroadcast();

        console2.log("CrePolicyConsumer:", address(consumer));
        console2.log("forwarder:        ", forwarder);
        console2.log("wired into guard: ", guard.isGuardian(msg.sender));
    }
}
