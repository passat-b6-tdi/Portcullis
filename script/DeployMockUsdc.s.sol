// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Script, console2 } from "forge-std/Script.sol";
import { MockERC20 } from "../test/mocks/MockERC20.sol";

contract DeployMockUsdc is Script {
    function run() external returns (MockERC20 usdc) {
        address receiver = vm.envOr("RECEIVER", address(0));
        uint256 floatAmount = vm.envOr("FLOAT", uint256(10_000_000e6));

        vm.startBroadcast();
        usdc = new MockERC20("USD Coin (mock)", "USDC", 6);
        if (receiver != address(0)) usdc.mint(receiver, floatAmount);
        vm.stopBroadcast();

        console2.log("MockERC20 (USDC):", address(usdc));
        console2.log("receiver funded: ", receiver);
        console2.log("float:           ", floatAmount);
    }
}
