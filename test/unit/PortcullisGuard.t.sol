// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";
import { PortcullisGuard } from "../../contracts/core/PortcullisGuard.sol";
import { PortcullisChecks } from "../../contracts/core/PortcullisChecks.sol";
import { SettlementMessage, TripReason } from "../../contracts/core/types/GuardTypes.sol";
import { MockIdentityRegistry } from "../mocks/MockIdentityRegistry.sol";

contract PortcullisGuardTest is Test {
    PortcullisGuard internal guard;
    MockIdentityRegistry internal identity;

    address internal guardianAddr = makeAddr("guardian");
    address internal sender = makeAddr("sender");
    address internal recipient = makeAddr("recipient");
    address internal token = makeAddr("token");
    address internal stranger = makeAddr("stranger");

    bytes32 internal constant SRC = keccak256("treasury.acme.portcullis.eth");

    event SentinelTripped(TripReason reason, bytes32 indexed messageId, address indexed reporter);
    event SettlementCleared(bytes32 indexed messageId, uint8 detectorMask);
    event SentinelCleared(address indexed guardian);

    function setUp() public {
        identity = new MockIdentityRegistry();
        identity.setAuthority(SRC, sender);

        guard = new PortcullisGuard(guardianAddr, identity);

        vm.startPrank(guardianAddr);
        guard.setBounds(1 ether, 1000 ether);
        guard.setAllowedToken(token, true);
        vm.stopPrank();
    }

    function _msg(uint256 value, uint256 nonce, bytes32 id) internal view returns (SettlementMessage memory) {
        return SettlementMessage({
            srcId: SRC, sender: sender, recipient: recipient, token: token, value: value, appNonce: nonce, messageId: id
        });
    }

    function test_constructor_setsGuardian() public view {
        assertEq(guard.guardian(), guardianAddr);
        assertEq(address(guard.identity()), address(identity));
        assertFalse(guard.paused());
    }

    function test_constructor_revertsOnZeroGuardian() public {
        vm.expectRevert(PortcullisGuard.Portcullis__ZeroAddress.selector);
        new PortcullisGuard(address(0), identity);
    }

    function test_constructor_revertsOnZeroIdentity() public {
        vm.expectRevert(PortcullisGuard.Portcullis__ZeroAddress.selector);
        new PortcullisGuard(guardianAddr, MockIdentityRegistry(address(0)));
    }

    function test_setters_onlyGuardian() public {
        vm.startPrank(stranger);
        vm.expectRevert(PortcullisGuard.Portcullis__NotGuardian.selector);
        guard.setBounds(1, 2);
        vm.expectRevert(PortcullisGuard.Portcullis__NotGuardian.selector);
        guard.setAllowedToken(token, true);
        vm.expectRevert(PortcullisGuard.Portcullis__NotGuardian.selector);
        guard.clear();
        vm.stopPrank();
    }

    function test_setBounds_revertsWhenMinAboveMax() public {
        vm.prank(guardianAddr);
        vm.expectRevert(PortcullisGuard.Portcullis__BadConfig.selector);
        guard.setBounds(10, 1);
    }

    function test_inspect_happyPath() public {
        SettlementMessage memory m = _msg(100 ether, 1, keccak256("m1"));

        vm.expectEmit(true, false, false, true, address(guard));
        emit SettlementCleared(m.messageId, PortcullisChecks.PASS_MASK);

        bool ok = guard.inspect(m, "");

        assertTrue(ok);
        assertFalse(guard.paused());
        assertTrue(guard.seen(m.messageId));
        assertEq(guard.lastNonce(SRC), 1);
    }

    function test_inspect_binding_unknownSource() public {
        SettlementMessage memory m = _msg(100 ether, 1, keccak256("m1"));
        m.srcId = keccak256("unknown");

        _expectTrip(TripReason.BINDING, m.messageId);
        bool ok = guard.inspect(m, "");

        assertFalse(ok);
        assertTrue(guard.paused());
        assertFalse(guard.seen(m.messageId));
        assertEq(guard.lastNonce(SRC), 0);
    }

    function test_inspect_binding_senderMismatch() public {
        SettlementMessage memory m = _msg(100 ether, 1, keccak256("m1"));
        m.sender = stranger;

        _expectTrip(TripReason.BINDING, m.messageId);
        assertFalse(guard.inspect(m, ""));
        assertTrue(guard.paused());
    }

    function test_inspect_bounds_valueTooLow() public {
        SettlementMessage memory m = _msg(0.5 ether, 1, keccak256("m1"));
        _expectTrip(TripReason.BOUNDS, m.messageId);
        assertFalse(guard.inspect(m, ""));
    }

    function test_inspect_bounds_valueTooHigh() public {
        SettlementMessage memory m = _msg(2000 ether, 1, keccak256("m1"));
        _expectTrip(TripReason.BOUNDS, m.messageId);
        assertFalse(guard.inspect(m, ""));
    }

    function test_inspect_bounds_tokenNotAllowed() public {
        SettlementMessage memory m = _msg(100 ether, 1, keccak256("m1"));
        m.token = makeAddr("otherToken");
        _expectTrip(TripReason.BOUNDS, m.messageId);
        assertFalse(guard.inspect(m, ""));
    }

    function test_inspect_bounds_zeroRecipient() public {
        SettlementMessage memory m = _msg(100 ether, 1, keccak256("m1"));
        m.recipient = address(0);
        _expectTrip(TripReason.BOUNDS, m.messageId);
        assertFalse(guard.inspect(m, ""));
    }

    function test_inspect_replay_sameMessageId() public {
        SettlementMessage memory first = _msg(100 ether, 1, keccak256("m1"));
        assertTrue(guard.inspect(first, ""));

        SettlementMessage memory again = _msg(100 ether, 2, keccak256("m1"));
        _expectTrip(TripReason.REPLAY, again.messageId);
        assertFalse(guard.inspect(again, ""));
        assertTrue(guard.paused());
    }

    function test_inspect_nonceGap() public {
        SettlementMessage memory m = _msg(100 ether, 2, keccak256("m1"));
        _expectTrip(TripReason.NONCE_GAP, m.messageId);
        assertFalse(guard.inspect(m, ""));
    }

    function test_inspect_sequentialNoncesPass() public {
        assertTrue(guard.inspect(_msg(10 ether, 1, keccak256("a")), ""));
        assertTrue(guard.inspect(_msg(10 ether, 2, keccak256("b")), ""));
        assertTrue(guard.inspect(_msg(10 ether, 3, keccak256("c")), ""));
        assertEq(guard.lastNonce(SRC), 3);
    }

    function test_inspect_revertsWhenPaused() public {
        SettlementMessage memory bad = _msg(100 ether, 1, keccak256("m1"));
        bad.sender = stranger;
        guard.inspect(bad, "");
        assertTrue(guard.paused());

        SettlementMessage memory good = _msg(100 ether, 1, keccak256("m2"));
        vm.expectRevert(PortcullisGuard.Portcullis__Paused.selector);
        guard.inspect(good, "");
    }

    function test_clear_restoresOperation() public {
        SettlementMessage memory bad = _msg(100 ether, 1, keccak256("m1"));
        bad.sender = stranger;
        guard.inspect(bad, "");
        assertTrue(guard.paused());

        vm.expectEmit(true, false, false, false, address(guard));
        emit SentinelCleared(guardianAddr);
        vm.prank(guardianAddr);
        guard.clear();

        assertFalse(guard.paused());
        assertTrue(guard.inspect(_msg(100 ether, 1, keccak256("m2")), ""));
    }

    function test_trip_doesNotMutateGuardLedger() public {
        guard.inspect(_msg(10 ether, 1, keccak256("a")), "");

        SettlementMessage memory bad = _msg(10 ether, 2, keccak256("b"));
        bad.sender = stranger;
        guard.inspect(bad, "");

        assertEq(guard.lastNonce(SRC), 1);
        assertFalse(guard.seen(keccak256("b")));
    }

    function test_transferGuardian_movesRole() public {
        vm.prank(guardianAddr);
        guard.transferGuardian(stranger);
        assertEq(guard.guardian(), stranger);

        vm.prank(guardianAddr);
        vm.expectRevert(PortcullisGuard.Portcullis__NotGuardian.selector);
        guard.clear();

        vm.prank(stranger);
        guard.clear();
    }

    function test_transferGuardian_onlyGuardian() public {
        vm.prank(stranger);
        vm.expectRevert(PortcullisGuard.Portcullis__NotGuardian.selector);
        guard.transferGuardian(stranger);
    }

    function test_transferGuardian_rejectsZero() public {
        vm.prank(guardianAddr);
        vm.expectRevert(PortcullisGuard.Portcullis__ZeroAddress.selector);
        guard.transferGuardian(address(0));
    }

    function _expectTrip(TripReason reason, bytes32 messageId) internal {
        vm.expectEmit(true, true, false, true, address(guard));
        emit SentinelTripped(reason, messageId, address(this));
    }
}
