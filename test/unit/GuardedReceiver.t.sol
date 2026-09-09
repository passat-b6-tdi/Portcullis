// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { PortcullisGuard } from "../../contracts/core/PortcullisGuard.sol";
import { SettlementMessage } from "../../contracts/core/types/GuardTypes.sol";
import { MockIdentityRegistry } from "../mocks/MockIdentityRegistry.sol";
import { AbiGuardedReceiver } from "../mocks/AbiGuardedReceiver.sol";
import { MockRelayer } from "../mocks/MockRelayer.sol";
import { GuardScenario } from "../util/GuardScenario.sol";

contract GuardedReceiverTest is GuardScenario {
    PortcullisGuard internal guard;
    MockIdentityRegistry internal identity;
    AbiGuardedReceiver internal receiver;
    MockRelayer internal relayer;

    address internal guardianAddr = makeAddr("guardian");
    address internal recipient = makeAddr("recipient");
    address internal token = makeAddr("token");

    bytes32 internal constant SRC = keccak256("src");

    event SettlementRejected(bytes32 indexed messageId);

    function setUp() public {
        identity = new MockIdentityRegistry();
        identity.setAuthority(SRC, authority);
        guard = new PortcullisGuard(guardianAddr, guardianAddr, address(identity));

        receiver = new AbiGuardedReceiver(guard);
        relayer = new MockRelayer();

        vm.startPrank(guardianAddr);
        guard.setBounds(1 ether, 1000 ether);
        guard.setAllowedToken(token, true, 18);
        guard.setEnrolled(SRC, true);
        guard.setAdapter(address(receiver), true);
        vm.stopPrank();
    }

    function _msg(uint256 value, uint256 nonce) internal view returns (SettlementMessage memory) {
        return SettlementMessage({
            srcId: SRC,
            recipient: recipient,
            token: token,
            value: value,
            appNonce: nonce,
            deadline: block.timestamp + 1 days
        });
    }

    function _deliver(uint256 value, uint256 nonce) internal {
        SettlementMessage memory m = _msg(value, nonce);
        relayer.send(receiver, m, _sign(guard, m));
    }

    function test_validMessage_isHandled() public {
        _deliver(100 ether, 1);
        assertEq(receiver.credited(recipient), 100 ether);
        assertEq(receiver.validatedCount(), 1);
        assertFalse(guard.paused());
    }

    function test_unauthenticatedMessage_isRejectedNotHandled() public {
        SettlementMessage memory m = _msg(100 ether, 1);

        vm.expectEmit(true, false, false, false, address(receiver));
        emit SettlementRejected(guard.digestOf(m));

        relayer.send(receiver, m, _signAs(guard, m, 0xBEEF)); // not the authority

        assertEq(receiver.credited(recipient), 0);
        assertEq(receiver.validatedCount(), 0);
        assertFalse(guard.paused()); // binding failure rejects, does not latch
    }

    function test_afterLatchingTrip_furtherDeliveryReverts() public {
        vm.prank(guardianAddr);
        guard.setRate(1, 0); // any in-bounds settlement now trips RATE_LIMIT (latching)

        _deliver(100 ether, 1);
        assertTrue(guard.paused());

        SettlementMessage memory m = _msg(100 ether, 1);
        vm.expectRevert(PortcullisGuard.Portcullis__Paused.selector);
        relayer.send(receiver, m, _sign(guard, m));
    }

    function test_malformedWire_reverts() public {
        vm.expectRevert();
        relayer.sendRaw(receiver, hex"deadbeef");
    }

    function test_sequentialDeliveries() public {
        _deliver(10 ether, 1);
        _deliver(20 ether, 2);
        assertEq(receiver.validatedCount(), 2);
        assertEq(guard.lastNonce(SRC), 2);
    }

    function test_nonAdapterReceiver_cannotDriveGuard() public {
        AbiGuardedReceiver rogue = new AbiGuardedReceiver(guard);
        SettlementMessage memory m = _msg(100 ether, 1);
        vm.expectRevert();
        relayer.send(rogue, m, _sign(guard, m));
    }
}
