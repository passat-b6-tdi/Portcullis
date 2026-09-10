// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Script, console2 } from "forge-std/Script.sol";
import { PortcullisGuard } from "../contracts/core/PortcullisGuard.sol";
import { IPreSettlementPolicy } from "../contracts/core/interfaces/IPreSettlementPolicy.sol";
import { SettlementMessage } from "../contracts/core/types/GuardTypes.sol";

interface IERC20Balance {
    function balanceOf(address) external view returns (uint256);
}

interface IReceiveMessage {
    function receiveMessage(bytes calldata wire) external;
}

contract SmokeArc is Script {
    function run() external {
        PortcullisGuard guard = PortcullisGuard(vm.envAddress("GUARD"));
        address receiver = vm.envAddress("RECEIVER");
        address token = vm.envAddress("TOKEN");
        uint256 authorityPk = vm.envUint("AUTHORITY_PK");

        address consumer = vm.envOr("CONSUMER", address(0));
        address recipient = vm.envOr("RECIPIENT", address(0xBEEF));
        uint256 value = vm.envOr("VALUE", uint256(200_000e6));
        bytes32 srcId = vm.envOr("SRC_ID", keccak256("treasury.acme.portcullis.eth"));

        SettlementMessage memory m = SettlementMessage({
            srcId: srcId,
            recipient: recipient,
            token: token,
            value: value,
            appNonce: guard.lastNonce(srcId) + 1,
            deadline: block.timestamp + 1 hours
        });

        bytes32 digest = keccak256(abi.encode(block.chainid, address(guard), m));
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));

        uint256 balBefore = IERC20Balance(token).balanceOf(recipient);
        console2.log("recipient balance before:", balBefore);
        console2.log("guard paused before:     ", guard.paused());

        // 1. forged: sign with a key that is not the registered authority
        (uint8 fv, bytes32 fr, bytes32 fs) = vm.sign(uint256(keccak256("not-the-authority")), ethHash);
        bytes memory forged = abi.encode(m, abi.encodePacked(fr, fs, fv));

        vm.startBroadcast();
        IReceiveMessage(receiver).receiveMessage(forged);
        vm.stopBroadcast();

        require(IERC20Balance(token).balanceOf(recipient) == balBefore, "forged message paid out");
        require(!guard.paused(), "forged message tripped the breaker");
        console2.log("forged message rejected, breaker still down: ok");

        // 2. genuine: unwire policy so POLICY_HOLD does not mask the happy path
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authorityPk, ethHash);
        bytes memory wire = abi.encode(m, abi.encodePacked(r, s, v));

        vm.startBroadcast();
        guard.setPolicy(IPreSettlementPolicy(address(0)));
        IReceiveMessage(receiver).receiveMessage(wire);
        if (consumer != address(0)) guard.setPolicy(IPreSettlementPolicy(consumer));
        vm.stopBroadcast();

        uint256 balAfter = IERC20Balance(token).balanceOf(recipient);
        console2.log("recipient balance after: ", balAfter);
        require(balAfter == balBefore + value, "genuine settlement did not pay out");
        console2.log("genuine settlement paid:", value);
        console2.log("policy restored:        ", address(guard) != address(0) && consumer != address(0));
    }
}
