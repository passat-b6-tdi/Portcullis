// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Script, console2 } from "forge-std/Script.sol";
import { PortcullisGuard } from "../contracts/core/PortcullisGuard.sol";
import { AddressBookRegistry } from "../contracts/identity/AddressBookRegistry.sol";
import { IVolumeVerdictOracle } from "../contracts/core/interfaces/IVolumeVerdictOracle.sol";

contract DeployCore is Script {
    function run() external returns (PortcullisGuard guard, AddressBookRegistry registry) {
        address deployer = msg.sender;
        address guardian = vm.envOr("GUARDIAN", deployer);

        uint256 minValue = vm.envOr("MIN_VALUE", uint256(1e18));
        uint256 maxValue = vm.envOr("MAX_VALUE", uint256(10_000_000e18));
        uint256 rateCapacity = vm.envOr("RATE_CAPACITY", uint256(5_000_000e18));
        uint256 rateRefill = vm.envOr("RATE_REFILL_PER_SEC", uint256(50e18));
        uint256 spikeFactorBps = vm.envOr("SPIKE_FACTOR_BPS", uint256(30_000));
        uint256 warmup = vm.envOr("VOLUME_WARMUP", uint256(10));

        vm.startBroadcast();
        registry = new AddressBookRegistry(deployer);
        guard = new PortcullisGuard(deployer, deployer, address(registry));

        guard.setBounds(minValue, maxValue);
        guard.setRate(rateCapacity, rateRefill);
        guard.setVolumePolicy(IVolumeVerdictOracle(address(0)), spikeFactorBps, warmup);

        if (guardian != deployer) {
            guard.transferGuardian(guardian);
            registry.transferOwnership(guardian);
        }
        vm.stopBroadcast();

        console2.log("AddressBookRegistry:", address(registry));
        console2.log("PortcullisGuard:    ", address(guard));
        console2.log("guardian:           ", guardian);
    }
}
