// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Script, console2 } from "forge-std/Script.sol";
import { EnsIdentityRegistry } from "../contracts/identity/EnsIdentityRegistry.sol";

contract DeployEns is Script {
    address constant SEPOLIA_UNIVERSAL_RESOLVER = 0xeEeEEEeE14D718C2B47D9923Deab1335E144EeEe;

    function run() external returns (EnsIdentityRegistry registry) {
        address universalResolver = vm.envOr("ENS_UNIVERSAL_RESOLVER", SEPOLIA_UNIVERSAL_RESOLVER);
        address owner = vm.envOr("ENS_OWNER", msg.sender);

        // optional: allowlist one source in the same tx
        bytes32 node = vm.envOr("ENS_NODE", bytes32(0));
        bytes memory dnsName = vm.envOr("ENS_DNS_NAME", bytes(""));

        vm.startBroadcast();
        registry = new EnsIdentityRegistry(universalResolver, owner);
        if (node != bytes32(0) && dnsName.length != 0 && owner == msg.sender) {
            registry.allow(node, dnsName);
        }
        vm.stopBroadcast();

        console2.log("EnsIdentityRegistry:", address(registry));
        console2.log("universalResolver:  ", universalResolver);
        console2.log("owner:              ", owner);
        if (node != bytes32(0)) console2.logBytes32(node);
    }
}
