// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";
import { PortcullisGuard } from "../../contracts/core/PortcullisGuard.sol";
import { IPreSettlementPolicy } from "../../contracts/core/interfaces/IPreSettlementPolicy.sol";
import { SettlementMessage, TripReason } from "../../contracts/core/types/GuardTypes.sol";
import { MockIdentityRegistry } from "../mocks/MockIdentityRegistry.sol";
import { MockPolicyOracle } from "../mocks/MockPolicyOracle.sol";

contract PolicyGateTest is Test {
    uint8 internal constant ALLOW = 0;
    uint8 internal constant MANUAL_REVIEW = 1;
    uint8 internal constant DENY = 2;

    PortcullisGuard internal guard;
    MockIdentityRegistry internal identity;
    MockPolicyOracle internal policy;

    address internal guardianAddr = makeAddr("guardian");
    address internal sender = makeAddr("sender");
    address internal recipient = makeAddr("recipient");
    address internal token = makeAddr("token");
    address internal attacker = makeAddr("attacker");

    bytes32 internal constant SRC = keccak256("src");

    event SentinelTripped(TripReason reason, bytes32 indexed messageId, address indexed reporter);

    function setUp() public {
        identity = new MockIdentityRegistry();
        identity.setAuthority(SRC, sender);
        guard = new PortcullisGuard(guardianAddr, identity);
        policy = new MockPolicyOracle();

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

    function _enable() internal {
        vm.prank(guardianAddr);
        guard.setPolicy(policy);
    }

    function test_unset_detectorSkipped() public {
        assertTrue(guard.inspect(_msg(100 ether, 1, keccak256("m")), ""));
    }

    function test_set_onlyGuardian() public {
        vm.expectRevert(PortcullisGuard.Portcullis__NotGuardian.selector);
        guard.setPolicy(policy);
    }

    function test_allow_passes() public {
        _enable();
        policy.set(ALLOW, 0);
        assertTrue(guard.inspect(_msg(100 ether, 1, keccak256("m")), ""));
        assertFalse(guard.paused());
    }

    function test_deny_trips() public {
        _enable();
        policy.set(DENY, 0x0F);
        SettlementMessage memory m = _msg(100 ether, 1, keccak256("m"));

        vm.expectEmit(true, true, false, true, address(guard));
        emit SentinelTripped(TripReason.POLICY, m.messageId, address(this));

        assertFalse(guard.inspect(m, ""));
        assertTrue(guard.paused());
    }

    function test_manualReview_trips() public {
        _enable();
        policy.set(MANUAL_REVIEW, 0);
        SettlementMessage memory m = _msg(100 ether, 1, keccak256("m"));

        vm.expectEmit(true, true, false, true, address(guard));
        emit SentinelTripped(TripReason.POLICY, m.messageId, address(this));

        assertFalse(guard.inspect(m, ""));
    }

    function test_policy_runsBeforeBinding() public {
        _enable();
        policy.set(DENY, 0);
        SettlementMessage memory m = _msg(100 ether, 1, keccak256("m"));
        m.sender = attacker; // would also fail BINDING

        vm.expectEmit(true, true, false, true, address(guard));
        emit SentinelTripped(TripReason.POLICY, m.messageId, address(this));

        assertFalse(guard.inspect(m, ""));
    }

    function test_deny_leavesLedgerUntouched() public {
        assertTrue(guard.inspect(_msg(10 ether, 1, keccak256("a")), ""));

        _enable();
        policy.set(DENY, 0);
        guard.inspect(_msg(10 ether, 2, keccak256("b")), "");

        assertEq(guard.lastNonce(SRC), 1);
        assertFalse(guard.seen(keccak256("b")));
    }
}
