// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";
import { PortcullisGuard } from "../../contracts/core/PortcullisGuard.sol";
import { GuardedReceiver } from "../../contracts/adapters/GuardedReceiver.sol";
import { SettlementMessage } from "../../contracts/core/types/GuardTypes.sol";
import { MockIdentityRegistry } from "../mocks/MockIdentityRegistry.sol";
import { AbiGuardedReceiver } from "../mocks/AbiGuardedReceiver.sol";
import { MockRelayer } from "../mocks/MockRelayer.sol";

contract GuardedReceiverTest is Test {
    PortcullisGuard internal guard;
    MockIdentityRegistry internal identity;
    AbiGuardedReceiver internal receiver;
    MockRelayer internal relayer;

    address internal guardianAddr = makeAddr("guardian");
    address internal sender = makeAddr("sender");
    address internal recipient = makeAddr("recipient");
    address internal token = makeAddr("token");
    address internal attacker = makeAddr("attacker");

    bytes32 internal constant SRC = keccak256("src");

    event SettlementRejected(bytes32 indexed messageId);

    function setUp() public {
        identity = new MockIdentityRegistry();
        identity.setAuthority(SRC, sender);
        guard = new PortcullisGuard(guardianAddr, identity);

        vm.startPrank(guardianAddr);
        guard.setBounds(1 ether, 1000 ether);
        guard.setAllowedToken(token, true);
        vm.stopPrank();

        receiver = new AbiGuardedReceiver(guard);
        relayer = new MockRelayer();
    }

    function _msg(uint256 value, uint256 nonce, bytes32 id) internal view returns (SettlementMessage memory) {
        return SettlementMessage({
            srcId: SRC, sender: sender, recipient: recipient, token: token, value: value, appNonce: nonce, messageId: id
        });
    }

    function test_validMessage_isHandled() public {
        relayer.send(receiver, _msg(100 ether, 1, keccak256("m1")), "");
        assertEq(receiver.credited(recipient), 100 ether);
        assertEq(receiver.validatedCount(), 1);
        assertFalse(guard.paused());
    }

    function test_hostileMessage_isRejectedNotHandled() public {
        SettlementMessage memory m = _msg(100 ether, 1, keccak256("m1"));
        m.sender = attacker;

        vm.expectEmit(true, false, false, false, address(receiver));
        emit SettlementRejected(m.messageId);

        relayer.send(receiver, m, "");

        assertEq(receiver.credited(recipient), 0);
        assertEq(receiver.validatedCount(), 0);
        assertTrue(guard.paused());
    }

    function test_afterTrip_furtherDeliveryReverts() public {
        relayer.spoofSender(receiver, _msg(100 ether, 1, keccak256("m1")), attacker);
        assertTrue(guard.paused());

        vm.expectRevert(PortcullisGuard.Portcullis__Paused.selector);
        relayer.send(receiver, _msg(100 ether, 1, keccak256("m2")), "");
    }

    function test_malformedWire_reverts() public {
        vm.expectRevert();
        relayer.sendRaw(receiver, hex"deadbeef");
    }

    function test_sequentialDeliveries() public {
        relayer.send(receiver, _msg(10 ether, 1, keccak256("a")), "");
        relayer.send(receiver, _msg(20 ether, 2, keccak256("b")), "");
        assertEq(receiver.validatedCount(), 2);
        assertEq(guard.lastNonce(SRC), 2);
    }
}
