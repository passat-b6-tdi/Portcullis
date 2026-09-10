// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Script, console2 } from "forge-std/Script.sol";
import { PortcullisGuard } from "../contracts/core/PortcullisGuard.sol";
import { SettlementMessage } from "../contracts/core/types/GuardTypes.sol";

interface IReceiveMessage {
    function receiveMessage(bytes calldata wire) external;
}

contract SeedFeed is Script {
    PortcullisGuard internal guard;
    address internal receiver;
    address internal token;
    address internal recipient;
    bytes32 internal srcId;
    uint256 internal authorityPk;
    uint256 internal baseNonce;

    function run() external {
        guard = PortcullisGuard(vm.envAddress("GUARD"));
        receiver = vm.envAddress("RECEIVER");
        token = vm.envAddress("TOKEN");
        recipient = vm.envOr("RECIPIENT", address(0xBEEF));
        srcId = vm.envOr("SRC_ID", keccak256("treasury.acme.portcullis.eth"));
        authorityPk = vm.envUint("AUTHORITY_PK");
        baseNonce = guard.lastNonce(srcId);

        uint256 goodValue = 200_000e6;
        uint64 future = uint64(block.timestamp + 1 hours);

        vm.startBroadcast();

        // 1-2. genuine passes
        _send(_msg(srcId, goodValue, baseNonce + 1, future), authorityPk, "PASS #1");
        _send(_msg(srcId, goodValue, baseNonce + 2, future), authorityPk, "PASS #2");

        // 3. EXPIRED
        _send(_msg(srcId, goodValue, baseNonce + 3, uint64(block.timestamp - 1)), authorityPk, "EXPIRED");

        // 4. BOUNDS
        _send(_msg(srcId, 50_000_000e6, baseNonce + 3, future), authorityPk, "BOUNDS (high)");

        // 5. BINDING
        _send(
            _msg(srcId, goodValue, baseNonce + 3, future), uint256(keccak256("not-the-authority")), "BINDING (bad sig)"
        );

        // 6. BINDING
        _send(_msg(keccak256("some.other.source"), goodValue, 1, future), authorityPk, "BINDING (unenrolled)");

        // 7. NONCE_GAP
        _send(_msg(srcId, goodValue, baseNonce + 9, future), authorityPk, "NONCE_GAP");

        // 8. another genuine pass
        _send(_msg(srcId, goodValue, baseNonce + 3, future), authorityPk, "PASS #3");

        // 9. REPLAY
        _send(_msg(srcId, goodValue, baseNonce + 1, future), authorityPk, "REPLAY");

        // 10. BOUNDS
        _send(_msg(srcId, 100_000, baseNonce + 4, future), authorityPk, "BOUNDS (low)");

        vm.stopBroadcast();

        console2.log("seeded 10 settlements against", address(guard));
        console2.log("lastNonce now:", guard.lastNonce(srcId));
    }

    function _msg(bytes32 sid, uint256 value, uint256 nonce, uint64 deadline)
        internal
        view
        returns (SettlementMessage memory m)
    {
        m = SettlementMessage({
            srcId: sid, recipient: recipient, token: token, value: value, appNonce: nonce, deadline: deadline
        });
    }

    function _send(SettlementMessage memory m, uint256 pk, string memory label) internal {
        bytes32 digest = keccak256(abi.encode(block.chainid, address(guard), m));
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, ethHash);
        IReceiveMessage(receiver).receiveMessage(abi.encode(m, abi.encodePacked(r, s, v)));
        console2.log("sent:", label);
    }
}
