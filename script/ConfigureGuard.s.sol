// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Script, console2 } from "forge-std/Script.sol";
import { PortcullisGuard } from "../contracts/core/PortcullisGuard.sol";
import { AddressBookRegistry } from "../contracts/identity/AddressBookRegistry.sol";
import { IPreSettlementPolicy } from "../contracts/core/interfaces/IPreSettlementPolicy.sol";

contract ConfigureGuard is Script {
    function run() external {
        PortcullisGuard guard = PortcullisGuard(vm.envAddress("GUARD"));
        AddressBookRegistry registry = AddressBookRegistry(vm.envAddress("REGISTRY"));

        bytes32 srcId = vm.envOr("SRC_ID", keccak256("treasury.acme.portcullis.eth"));
        address authority = vm.envAddress("SRC_AUTHORITY");
        address adapter = vm.envOr("ADAPTER", address(0));
        address policy = vm.envOr("POLICY", address(0));
        address allowToken = vm.envOr("ALLOW_TOKEN", address(0));
        uint8 allowTokenDecimals = uint8(vm.envOr("ALLOW_TOKEN_DECIMALS", uint256(6)));

        vm.startBroadcast();
        registry.setAuthority(srcId, authority);
        if (guard.isGuardian(msg.sender)) {
            guard.setEnrolled(srcId, true);
            if (allowToken != address(0)) guard.setAllowedToken(allowToken, true, allowTokenDecimals);
            if (adapter != address(0)) guard.setAdapter(adapter, true);
            if (policy != address(0)) guard.setPolicy(IPreSettlementPolicy(policy));
        }
        vm.stopBroadcast();

        console2.log("srcId authority set:", authority);
        console2.logBytes32(srcId);
        console2.log("enrolled:", guard.enrolled(srcId));
        console2.log("adapter:", adapter);
        console2.log("policy:", policy);
    }
}
