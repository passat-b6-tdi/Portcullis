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
    PortcullisGuard internal guard;
    address internal receiver;
    address internal token;
    address internal recipient;
    uint256 internal value;
    bytes32 internal srcId;

    function run() external {
        guard = PortcullisGuard(vm.envAddress("GUARD"));
        receiver = vm.envAddress("RECEIVER");
        token = vm.envAddress("TOKEN");
        recipient = vm.envOr("RECIPIENT", address(0xBEEF));
        value = vm.envOr("VALUE", uint256(200_000e6));
        srcId = vm.envOr("SRC_ID", keccak256("treasury.acme.portcullis.eth"));

        uint256 authorityPk = vm.envUint("AUTHORITY_PK");
        address consumer = vm.envOr("CONSUMER", address(0));

        uint256 balBefore = IERC20Balance(token).balanceOf(recipient);
        console2.log("recipient balance before:", balBefore);
        console2.log("guard paused before:     ", guard.paused());

        _forgedRejected();
        require(IERC20Balance(token).balanceOf(recipient) == balBefore, "forged message paid out");
        require(!guard.paused(), "forged message tripped the breaker");
        console2.log("forged rejected, breaker down: ok");

        _genuinePaid(authorityPk, consumer);
        uint256 balAfter = IERC20Balance(token).balanceOf(recipient);
        console2.log("recipient balance after: ", balAfter);
        require(balAfter == balBefore + value, "genuine settlement did not pay out");
        console2.log("genuine settlement paid: ", value);
    }

    function _message() internal view returns (SettlementMessage memory m) {
        m = SettlementMessage({
            srcId: srcId,
            recipient: recipient,
            token: token,
            value: value,
            appNonce: guard.lastNonce(srcId) + 1,
            deadline: block.timestamp + 1 hours
        });
    }

    function _wire(SettlementMessage memory m, uint256 pk) internal view returns (bytes memory) {
        bytes32 digest = keccak256(abi.encode(block.chainid, address(guard), m));
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, ethHash);
        return abi.encode(m, abi.encodePacked(r, s, v));
    }

    function _forgedRejected() internal {
        bytes memory forged = _wire(_message(), uint256(keccak256("not-the-authority")));
        vm.broadcast();
        IReceiveMessage(receiver).receiveMessage(forged);
    }

    function _genuinePaid(uint256 authorityPk, address consumer) internal {
        bytes memory wire = _wire(_message(), authorityPk);
        vm.startBroadcast();
        guard.setPolicy(IPreSettlementPolicy(address(0)));
        IReceiveMessage(receiver).receiveMessage(wire);
        if (consumer != address(0)) guard.setPolicy(IPreSettlementPolicy(consumer));
        vm.stopBroadcast();
    }
}
