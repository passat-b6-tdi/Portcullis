// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Script, console2 } from "forge-std/Script.sol";
import { EnsIdentityRegistry } from "../contracts/identity/EnsIdentityRegistry.sol";

contract DnsEncode is Script {
    function run() external view {
        string memory name = vm.envString("NAME");
        string[] memory labels = vm.split(name, ".");

        bytes32 node = bytes32(0);
        bytes memory dns = "";
        for (uint256 i = labels.length; i > 0; i--) {
            bytes memory label = bytes(labels[i - 1]);
            require(label.length != 0 && label.length < 64, "bad label");
            node = keccak256(abi.encodePacked(node, keccak256(label)));
        }
        for (uint256 i = 0; i < labels.length; i++) {
            bytes memory label = bytes(labels[i]);
            dns = abi.encodePacked(dns, uint8(label.length), label);
        }
        dns = abi.encodePacked(dns, uint8(0));

        console2.log("name:     ", name);
        console2.log("namehash (srcId / ENS_NODE):");
        console2.logBytes32(node);
        console2.log("DNS wire  (ENS_DNS_NAME):");
        console2.logBytes(dns);
    }
}

contract ResolveEns is Script {
    function run() external view {
        EnsIdentityRegistry registry = EnsIdentityRegistry(vm.envAddress("REGISTRY"));
        bytes32 node = vm.envBytes32("ENS_NODE");

        address authority = registry.resolve(node);
        console2.log("registry:  ", address(registry));
        console2.logBytes32(node);
        console2.log("resolved authority:", authority);
        require(
            authority != address(0), "resolve returned address(0) - name not allowlisted or no on-chain addr record"
        );
    }
}
