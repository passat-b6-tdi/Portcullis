// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";
import { PortcullisGuard } from "../../contracts/core/PortcullisGuard.sol";
import { SettlementMessage, TripReason } from "../../contracts/core/types/GuardTypes.sol";
import { MockIdentityRegistry } from "../mocks/MockIdentityRegistry.sol";

contract RateLimitTest is Test {
    PortcullisGuard internal guard;
    MockIdentityRegistry internal identity;

    address internal guardianAddr = makeAddr("guardian");
    address internal sender = makeAddr("sender");
    address internal recipient = makeAddr("recipient");
    address internal token = makeAddr("token");

    bytes32 internal constant SRC = keccak256("src");

    event SentinelTripped(TripReason reason, bytes32 indexed messageId, address indexed reporter);

    function setUp() public {
        identity = new MockIdentityRegistry();
        identity.setAuthority(SRC, sender);
        guard = new PortcullisGuard(guardianAddr, identity);

        vm.startPrank(guardianAddr);
        guard.setBounds(1, 1_000_000 ether);
        guard.setAllowedToken(token, true);
        guard.setRate(1000 ether, 1 ether);
        vm.stopPrank();
    }

    function _msg(uint256 value, uint256 nonce, bytes32 id) internal view returns (SettlementMessage memory) {
        return SettlementMessage({
            srcId: SRC, sender: sender, recipient: recipient, token: token, value: value, appNonce: nonce, messageId: id
        });
    }

    function test_setRate_fillsBucket() public view {
        (uint256 capacity, uint256 refill, uint256 tokens,) = guard.rateState();
        assertEq(capacity, 1000 ether);
        assertEq(refill, 1 ether);
        assertEq(tokens, 1000 ether);
    }

    function test_withinCapacity_passesAndDrains() public {
        assertTrue(guard.inspect(_msg(400 ether, 1, keccak256("a")), ""));
        (,, uint256 tokens,) = guard.rateState();
        assertEq(tokens, 600 ether);

        assertTrue(guard.inspect(_msg(600 ether, 2, keccak256("b")), ""));
        (,, tokens,) = guard.rateState();
        assertEq(tokens, 0);
    }

    function test_overCapacity_trips() public {
        SettlementMessage memory m = _msg(1001 ether, 1, keccak256("a"));
        vm.expectEmit(true, true, false, true, address(guard));
        emit SentinelTripped(TripReason.RATE_LIMIT, m.messageId, address(this));
        assertFalse(guard.inspect(m, ""));
        assertTrue(guard.paused());
    }

    function test_drainThenExceed_trips() public {
        assertTrue(guard.inspect(_msg(1000 ether, 1, keccak256("a")), ""));

        SettlementMessage memory m = _msg(1 ether, 2, keccak256("b"));
        _expectTrip(TripReason.RATE_LIMIT, m.messageId);
        assertFalse(guard.inspect(m, ""));
    }

    function test_refillOverTime_restoresAllowance() public {
        assertTrue(guard.inspect(_msg(1000 ether, 1, keccak256("a")), ""));

        vm.warp(block.timestamp + 300);

        assertTrue(guard.inspect(_msg(300 ether, 2, keccak256("b")), ""));
        (,, uint256 tokens,) = guard.rateState();
        assertEq(tokens, 0);
    }

    function test_refillCapsAtCapacity() public {
        assertTrue(guard.inspect(_msg(1000 ether, 1, keccak256("a")), ""));
        vm.warp(block.timestamp + 10_000_000);

        SettlementMessage memory m = _msg(1001 ether, 2, keccak256("b"));
        _expectTrip(TripReason.RATE_LIMIT, m.messageId);
        assertFalse(guard.inspect(m, ""));
    }

    function test_rateDisabled_whenCapacityZero() public {
        PortcullisGuard g = new PortcullisGuard(guardianAddr, identity);
        vm.startPrank(guardianAddr);
        g.setBounds(1, 1_000_000 ether);
        g.setAllowedToken(token, true);
        vm.stopPrank();

        assertTrue(g.inspect(_msg(999_999 ether, 1, keccak256("a")), ""));
        assertFalse(g.paused());
    }

    function _expectTrip(TripReason reason, bytes32 messageId) internal {
        vm.expectEmit(true, true, false, true, address(guard));
        emit SentinelTripped(reason, messageId, address(this));
    }
}
