// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { PortcullisGuard } from "../../contracts/core/PortcullisGuard.sol";
import { SettlementMessage, TripReason } from "../../contracts/core/types/GuardTypes.sol";
import { MockIdentityRegistry } from "../mocks/MockIdentityRegistry.sol";
import { GuardScenario } from "../util/GuardScenario.sol";

contract RateLimitTest is GuardScenario {
    PortcullisGuard internal guard;
    MockIdentityRegistry internal identity;

    address internal guardianAddr = makeAddr("guardian");
    address internal recipient = makeAddr("recipient");
    address internal token = makeAddr("token");

    bytes32 internal constant SRC = keccak256("src");

    event SentinelTripped(TripReason reason, bytes32 indexed messageId, address indexed reporter);

    function setUp() public {
        identity = new MockIdentityRegistry();
        identity.setAuthority(SRC, authority);
        guard = new PortcullisGuard(guardianAddr, guardianAddr, address(identity));

        vm.startPrank(guardianAddr);
        guard.setBounds(1, 1_000_000 ether);
        guard.setAllowedToken(token, true, 18);
        guard.setRate(1000 ether, 1 ether);
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

    function test_setRate_fillsBucket() public view {
        (uint256 capacity, uint256 refill, uint256 tokens,) = guard.rateState();
        assertEq(capacity, 1000 ether);
        assertEq(refill, 1 ether);
        assertEq(tokens, 1000 ether);
    }

    function test_withinCapacity_passesAndDrains() public {
        assertTrue(_pass(400 ether, 1));
        (,, uint256 tokens,) = guard.rateState();
        assertEq(tokens, 600 ether);

        assertTrue(_pass(600 ether, 2));
        (,, tokens,) = guard.rateState();
        assertEq(tokens, 0);
    }

    function test_overCapacity_trips() public {
        SettlementMessage memory m = _msg(1001 ether, 1);
        _expectTrip(TripReason.RATE_LIMIT, guard.digestOf(m));
        assertFalse(guard.inspect(m, _sign(guard, m)));
        assertTrue(guard.paused());
    }

    function test_drainThenExceed_trips() public {
        assertTrue(_pass(1000 ether, 1));

        SettlementMessage memory m = _msg(1 ether, 2);
        _expectTrip(TripReason.RATE_LIMIT, guard.digestOf(m));
        assertFalse(guard.inspect(m, _sign(guard, m)));
    }

    function test_refillOverTime_restoresAllowance() public {
        assertTrue(_pass(1000 ether, 1));

        vm.warp(block.timestamp + 300);

        assertTrue(_pass(300 ether, 2));
        (,, uint256 tokens,) = guard.rateState();
        assertEq(tokens, 0);
    }

    function test_refillCapsAtCapacity() public {
        assertTrue(_pass(1000 ether, 1));
        vm.warp(block.timestamp + 10_000_000);

        SettlementMessage memory m = _msg(1001 ether, 2);
        _expectTrip(TripReason.RATE_LIMIT, guard.digestOf(m));
        assertFalse(guard.inspect(m, _sign(guard, m)));
    }

    function test_rateDisabled_whenCapacityZero() public {
        PortcullisGuard g = new PortcullisGuard(guardianAddr, guardianAddr, address(identity));
        vm.startPrank(guardianAddr);
        g.setBounds(1, 1_000_000 ether);
        g.setAllowedToken(token, true, 18);
        g.setEnrolled(SRC, true);
        g.setAdapter(address(this), true);
        vm.stopPrank();

        SettlementMessage memory m = _msg(999_999 ether, 1);
        assertTrue(g.inspect(m, _sign(g, m)));
        assertFalse(g.paused());
    }

    function _expectTrip(TripReason reason, bytes32 messageId) internal {
        vm.expectEmit(true, true, false, true, address(guard));
        emit SentinelTripped(reason, messageId, address(this));
    }
}
