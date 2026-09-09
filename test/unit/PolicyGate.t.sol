// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Ownable } from "solady/auth/Ownable.sol";
import { PortcullisGuard } from "../../contracts/core/PortcullisGuard.sol";
import { IPreSettlementPolicy } from "../../contracts/core/interfaces/IPreSettlementPolicy.sol";
import { SettlementMessage, TripReason } from "../../contracts/core/types/GuardTypes.sol";
import { MockIdentityRegistry } from "../mocks/MockIdentityRegistry.sol";
import { MockPolicyOracle } from "../mocks/MockPolicyOracle.sol";
import { GuardScenario } from "../util/GuardScenario.sol";

contract PolicyGateTest is GuardScenario {
    uint8 internal constant ALLOW = 1;
    uint8 internal constant DENY = 2;
    uint8 internal constant MANUAL_REVIEW = 3;

    PortcullisGuard internal guard;
    MockIdentityRegistry internal identity;
    MockPolicyOracle internal policy;

    address internal guardianAddr = makeAddr("guardian");
    address internal recipient = makeAddr("recipient");
    address internal token = makeAddr("token");

    bytes32 internal constant SRC = keccak256("src");

    event SentinelTripped(TripReason reason, bytes32 indexed messageId, address indexed reporter);

    function setUp() public {
        identity = new MockIdentityRegistry();
        identity.setAuthority(SRC, authority);
        guard = new PortcullisGuard(guardianAddr, guardianAddr, address(identity));
        policy = new MockPolicyOracle();

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

    function _inspect(SettlementMessage memory m) internal returns (bool) {
        return guard.inspect(m, _sign(guard, m));
    }

    function _enable() internal {
        vm.prank(guardianAddr);
        guard.setPolicy(policy);
    }

    function test_unset_detectorSkipped() public {
        assertTrue(_inspect(_msg(100 ether, 1)));
    }

    function test_set_onlyGuardian() public {
        vm.prank(makeAddr("stranger"));
        vm.expectRevert(Ownable.Unauthorized.selector);
        guard.setPolicy(policy);
    }

    function test_allow_passes() public {
        _enable();
        policy.set(ALLOW, 0);
        assertTrue(_inspect(_msg(100 ether, 1)));
        assertFalse(guard.paused());
    }

    function test_deny_trips() public {
        _enable();
        policy.set(DENY, 0x0F);
        SettlementMessage memory m = _msg(100 ether, 1);

        vm.expectEmit(true, true, false, true, address(guard));
        emit SentinelTripped(TripReason.POLICY, guard.digestOf(m), address(this));

        assertFalse(_inspect(m));
        assertTrue(guard.paused());
    }

    function test_manualReview_holdsWithoutLatching() public {
        _enable();
        policy.set(MANUAL_REVIEW, 0);
        assertFalse(_inspect(_msg(100 ether, 1)));
        assertFalse(guard.paused()); // MANUAL_REVIEW rejects the message, does not latch the breaker
    }

    function test_binding_runsBeforePolicy() public {
        _enable();
        policy.set(DENY, 0);
        SettlementMessage memory m = _msg(100 ether, 1);

        // bad signature => BINDING rejects first; policy (and its latch) never runs
        assertFalse(guard.inspect(m, _signAs(guard, m, 0xBEEF)));
        assertFalse(guard.paused());
    }

    function test_deny_leavesLedgerUntouched() public {
        assertTrue(_inspect(_msg(10 ether, 1)));

        _enable();
        policy.set(DENY, 0);
        SettlementMessage memory bad = _msg(10 ether, 2);
        _inspect(bad);

        assertEq(guard.lastNonce(SRC), 1);
        assertFalse(guard.seen(guard.digestOf(bad)));
    }
}
