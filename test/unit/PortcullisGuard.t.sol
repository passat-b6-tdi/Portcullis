// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Ownable } from "solady/auth/Ownable.sol";
import { AddressHelper } from "../../contracts/AddressHelper.sol";
import { PortcullisGuard } from "../../contracts/core/PortcullisGuard.sol";
import { PortcullisChecks } from "../../contracts/core/PortcullisChecks.sol";
import { SettlementMessage, TripReason } from "../../contracts/core/types/GuardTypes.sol";
import { MockIdentityRegistry } from "../mocks/MockIdentityRegistry.sol";
import { GuardScenario } from "../util/GuardScenario.sol";

contract PortcullisGuardTest is GuardScenario {
    PortcullisGuard internal guard;
    MockIdentityRegistry internal identity;

    address internal guardianAddr = makeAddr("guardian");
    address internal recipient = makeAddr("recipient");
    address internal token = makeAddr("token");
    address internal stranger = makeAddr("stranger");

    bytes32 internal constant SRC = keccak256("treasury.acme.portcullis.eth");

    event SentinelTripped(TripReason reason, bytes32 indexed messageId, address indexed reporter);
    event SettlementInspected(
        bytes32 indexed messageId,
        bytes32 indexed srcId,
        address recipient,
        address token,
        uint256 value,
        bool cleared,
        TripReason reason,
        uint8 detectorMask
    );
    event SentinelCleared(address indexed guardian);

    function setUp() public {
        identity = new MockIdentityRegistry();
        identity.setAuthority(SRC, authority);

        guard = new PortcullisGuard(guardianAddr, guardianAddr, address(identity));

        vm.startPrank(guardianAddr);
        guard.setBounds(1 ether, 1000 ether);
        guard.setAllowedToken(token, true, 18);
        guard.setEnrolled(SRC, true);
        guard.setAdapter(address(this), true);
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

    function _pass(uint256 value, uint256 nonce) internal returns (bool) {
        SettlementMessage memory m = _msg(value, nonce);
        return guard.inspect(m, _sign(guard, m));
    }

    function test_constructor_setsGuardian() public view {
        assertEq(guard.owner(), guardianAddr);
        assertTrue(guard.isGuardian(guardianAddr));
        assertEq(address(guard.identity()), address(identity));
        assertFalse(guard.paused());
    }

    function test_constructor_revertsOnZeroOwner() public {
        vm.expectRevert(AddressHelper.ZeroAddress.selector);
        new PortcullisGuard(address(0), guardianAddr, address(identity));
    }

    function test_constructor_revertsOnZeroGuardian() public {
        vm.expectRevert(AddressHelper.ZeroAddress.selector);
        new PortcullisGuard(guardianAddr, address(0), address(identity));
    }

    function test_constructor_revertsOnZeroIdentity() public {
        vm.expectRevert(AddressHelper.ZeroAddress.selector);
        new PortcullisGuard(guardianAddr, guardianAddr, address(0));
    }

    function test_setters_onlyGuardian() public {
        vm.startPrank(stranger);
        vm.expectRevert(Ownable.Unauthorized.selector);
        guard.setBounds(1, 2);
        vm.expectRevert(Ownable.Unauthorized.selector);
        guard.setAllowedToken(token, true, 18);
        vm.expectRevert(Ownable.Unauthorized.selector);
        guard.setEnrolled(SRC, true);
        vm.expectRevert(Ownable.Unauthorized.selector);
        guard.setAdapter(stranger, true);
        vm.expectRevert(Ownable.Unauthorized.selector);
        guard.clear();
        vm.stopPrank();
    }

    function test_inspect_onlyAdapter() public {
        SettlementMessage memory m = _msg(100 ether, 1);
        vm.prank(stranger);
        vm.expectRevert(Ownable.Unauthorized.selector);
        guard.inspect(m, _sign(guard, m));
    }

    function test_setBounds_revertsWhenMinAboveMax() public {
        vm.prank(guardianAddr);
        vm.expectRevert(PortcullisGuard.Portcullis__BadConfig.selector);
        guard.setBounds(10, 1);
    }

    function test_inspect_happyPath() public {
        SettlementMessage memory m = _msg(100 ether, 1);
        bytes32 mid = guard.digestOf(m);

        vm.expectEmit(true, true, false, true, address(guard));
        emit SettlementInspected(
            mid, SRC, recipient, token, 100 ether, true, TripReason.NONE, PortcullisChecks.PASS_MASK
        );

        bool ok = guard.inspect(m, _sign(guard, m));

        assertTrue(ok);
        assertFalse(guard.paused());
        assertTrue(guard.seen(mid));
        assertEq(guard.lastNonce(SRC), 1);
    }

    function test_inspect_binding_unenrolledSource() public {
        SettlementMessage memory m = _msg(100 ether, 1);
        m.srcId = keccak256("unknown");

        bool ok = guard.inspect(m, _sign(guard, m));

        assertFalse(ok);
        assertFalse(guard.paused()); // binding failures reject, they do not latch
        assertFalse(guard.seen(guard.digestOf(m)));
        assertEq(guard.lastNonce(SRC), 0);
    }

    function test_inspect_binding_badSignature() public {
        SettlementMessage memory m = _msg(100 ether, 1);
        bytes memory forged = _signAs(guard, m, 0xBEEF); // not the authority

        assertFalse(guard.inspect(m, forged));
        assertFalse(guard.paused());
    }

    function test_inspect_binding_emptyProof() public {
        SettlementMessage memory m = _msg(100 ether, 1);
        assertFalse(guard.inspect(m, ""));
        assertFalse(guard.paused());
    }

    function test_inspect_expired() public {
        SettlementMessage memory m = _msg(100 ether, 1);
        m.deadline = block.timestamp - 1;
        assertFalse(guard.inspect(m, _sign(guard, m)));
        assertFalse(guard.paused());
    }

    function test_inspect_bounds_valueTooLow() public {
        SettlementMessage memory m = _msg(0.5 ether, 1);
        assertFalse(guard.inspect(m, _sign(guard, m)));
        assertFalse(guard.paused());
    }

    function test_inspect_bounds_valueTooHigh() public {
        SettlementMessage memory m = _msg(2000 ether, 1);
        assertFalse(guard.inspect(m, _sign(guard, m)));
    }

    function test_inspect_bounds_tokenNotAllowed() public {
        SettlementMessage memory m = _msg(100 ether, 1);
        m.token = makeAddr("otherToken");
        assertFalse(guard.inspect(m, _sign(guard, m)));
    }

    function test_inspect_bounds_zeroRecipient() public {
        SettlementMessage memory m = _msg(100 ether, 1);
        m.recipient = address(0);
        assertFalse(guard.inspect(m, _sign(guard, m)));
    }

    // F6: a 6-decimal token's raw value is normalised to 18 dp before the shared
    // bounds (1..1000 ether) are applied — no 10^12 blind spot
    function test_tokenScale_normalisesDecimals() public {
        address usdc = makeAddr("usdc");
        vm.prank(guardianAddr);
        guard.setAllowedToken(usdc, true, 6);
        assertEq(guard.tokenScale(usdc), 1e12);

        // 500 "USDC" (500e6) -> 500 ether normalised, in bounds
        SettlementMessage memory ok = _msg(500e6, 1);
        ok.token = usdc;
        assertTrue(guard.inspect(ok, _sign(guard, ok)));

        // 2000 "USDC" (2000e6) -> 2000 ether normalised, over the 1000-ether max
        SettlementMessage memory hi = _msg(2000e6, 2);
        hi.token = usdc;
        assertFalse(guard.inspect(hi, _sign(guard, hi)));
        assertFalse(guard.paused());
    }

    function test_setAllowedToken_rejectsOver18Decimals() public {
        vm.prank(guardianAddr);
        vm.expectRevert(PortcullisGuard.Portcullis__BadConfig.selector);
        guard.setAllowedToken(makeAddr("weird"), true, 19);
    }

    function test_inspect_replay_sameMessage() public {
        assertTrue(_pass(100 ether, 1));

        SettlementMessage memory again = _msg(100 ether, 1);
        assertFalse(guard.inspect(again, _sign(guard, again)));
        assertFalse(guard.paused()); // replay rejects, does not latch
    }

    function test_inspect_nonceGap() public {
        SettlementMessage memory m = _msg(100 ether, 2);
        assertFalse(guard.inspect(m, _sign(guard, m)));
        assertFalse(guard.paused());
    }

    function test_inspect_sequentialNoncesPass() public {
        assertTrue(_pass(10 ether, 1));
        assertTrue(_pass(10 ether, 2));
        assertTrue(_pass(10 ether, 3));
        assertEq(guard.lastNonce(SRC), 3);
    }

    function test_inspect_revertsWhenPaused() public {
        vm.prank(guardianAddr);
        guard.setRate(1, 0); // capacity 1 wei => next in-bounds settlement trips RATE_LIMIT (latching)

        SettlementMessage memory bad = _msg(100 ether, 1);
        _expectTrip(TripReason.RATE_LIMIT, guard.digestOf(bad));
        guard.inspect(bad, _sign(guard, bad));
        assertTrue(guard.paused());

        SettlementMessage memory good = _msg(100 ether, 1);
        vm.expectRevert(PortcullisGuard.Portcullis__Paused.selector);
        guard.inspect(good, _sign(guard, good));
    }

    function test_clear_restoresOperation() public {
        vm.prank(guardianAddr);
        guard.setRate(1, 0);

        SettlementMessage memory bad = _msg(100 ether, 1);
        guard.inspect(bad, _sign(guard, bad));
        assertTrue(guard.paused());

        vm.prank(guardianAddr);
        guard.setRate(0, 0); // disable rate so the retry can pass

        vm.expectEmit(true, false, false, false, address(guard));
        emit SentinelCleared(guardianAddr);
        vm.prank(guardianAddr);
        guard.clear();

        assertFalse(guard.paused());
        assertTrue(_pass(100 ether, 1));
    }

    function test_rejectedMessage_doesNotMutateGuardLedger() public {
        assertTrue(_pass(10 ether, 1));

        SettlementMessage memory bad = _msg(10 ether, 2);
        guard.inspect(bad, _signAs(guard, bad, 0xBEEF)); // bad signature -> BINDING reject

        assertEq(guard.lastNonce(SRC), 1);
        assertFalse(guard.seen(guard.digestOf(bad)));
        assertFalse(guard.paused());
    }

    function test_resetSeen_releasesBurnedMessageId() public {
        SettlementMessage memory m = _msg(100 ether, 1);
        bytes32 mid = guard.digestOf(m);
        assertTrue(guard.inspect(m, _sign(guard, m)));
        assertTrue(guard.seen(mid));

        vm.prank(guardianAddr);
        guard.resetSeen(mid);
        assertFalse(guard.seen(mid));
    }

    function test_resyncNonce_realignsChannel() public {
        assertTrue(_pass(10 ether, 1));
        assertTrue(_pass(10 ether, 2));

        vm.prank(guardianAddr);
        guard.resyncNonce(SRC, 0);
        assertEq(guard.lastNonce(SRC), 0);

        // a fresh message (distinct digest) at the realigned nonce clears again
        assertTrue(_pass(11 ether, 1));
    }

    function test_recovery_onlyGuardian() public {
        vm.startPrank(stranger);
        vm.expectRevert(Ownable.Unauthorized.selector);
        guard.resetSeen(bytes32(0));
        vm.expectRevert(Ownable.Unauthorized.selector);
        guard.resyncNonce(SRC, 0);
        vm.stopPrank();
    }

    function test_setAdapter_grantsAndRevokes() public {
        address relay = makeAddr("relay");
        assertFalse(guard.isAdapter(relay));

        vm.prank(guardianAddr);
        guard.setAdapter(relay, true);
        assertTrue(guard.isAdapter(relay));

        vm.prank(guardianAddr);
        guard.setAdapter(relay, false);
        assertFalse(guard.isAdapter(relay));
    }

    function test_transferGuardian_movesRole() public {
        vm.prank(guardianAddr);
        guard.transferGuardian(stranger);
        assertTrue(guard.isGuardian(stranger));
        assertFalse(guard.isGuardian(guardianAddr));

        vm.prank(guardianAddr);
        vm.expectRevert(Ownable.Unauthorized.selector);
        guard.clear();

        vm.prank(stranger);
        guard.clear();
    }

    function test_transferGuardian_onlyGuardian() public {
        vm.prank(stranger);
        vm.expectRevert(Ownable.Unauthorized.selector);
        guard.transferGuardian(stranger);
    }

    function test_transferGuardian_rejectsZero() public {
        vm.prank(guardianAddr);
        vm.expectRevert(AddressHelper.ZeroAddress.selector);
        guard.transferGuardian(address(0));
    }

    function test_transferGuardian_rejectsSelf() public {
        vm.prank(guardianAddr);
        vm.expectRevert(PortcullisGuard.Portcullis__BadConfig.selector);
        guard.transferGuardian(guardianAddr);
    }

    function _expectTrip(TripReason reason, bytes32 messageId) internal {
        vm.expectEmit(true, true, false, true, address(guard));
        emit SentinelTripped(reason, messageId, address(this));
    }
}
