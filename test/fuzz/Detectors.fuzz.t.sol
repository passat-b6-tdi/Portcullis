// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { PortcullisGuard } from "../../contracts/core/PortcullisGuard.sol";
import { SettlementMessage } from "../../contracts/core/types/GuardTypes.sol";
import { MockIdentityRegistry } from "../mocks/MockIdentityRegistry.sol";
import { GuardScenario } from "../util/GuardScenario.sol";

contract DetectorsFuzzTest is GuardScenario {
    PortcullisGuard internal guard;
    MockIdentityRegistry internal identity;

    address internal guardianAddr = makeAddr("guardian");
    address internal recipient = makeAddr("recipient");
    address internal token = makeAddr("token");

    bytes32 internal constant SRC = keccak256("src");
    uint256 internal constant MIN = 1 ether;
    uint256 internal constant MAX = 1000 ether;

    function setUp() public {
        identity = new MockIdentityRegistry();
        identity.setAuthority(SRC, authority);
        guard = new PortcullisGuard(guardianAddr, guardianAddr, address(identity));
        vm.startPrank(guardianAddr);
        guard.setBounds(MIN, MAX);
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

    function testFuzz_inRangeValuePasses(uint256 value) public {
        value = bound(value, MIN, MAX);
        SettlementMessage memory m = _msg(value, 1);
        assertTrue(guard.inspect(m, _sign(guard, m)));
        assertFalse(guard.paused());
    }

    function testFuzz_belowMinRejectsWithoutLatching(uint256 value) public {
        value = bound(value, 0, MIN - 1);
        SettlementMessage memory m = _msg(value, 1);
        assertFalse(guard.inspect(m, _sign(guard, m)));
        assertFalse(guard.paused());
    }

    function testFuzz_aboveMaxRejectsWithoutLatching(uint256 value) public {
        value = bound(value, MAX + 1, type(uint128).max);
        SettlementMessage memory m = _msg(value, 1);
        assertFalse(guard.inspect(m, _sign(guard, m)));
        assertFalse(guard.paused());
    }

    function testFuzz_badSignatureRejects(uint256 badPk) public {
        badPk = bound(badPk, 1, type(uint128).max);
        vm.assume(badPk != AUTHORITY_PK);
        SettlementMessage memory m = _msg(100 ether, 1);
        assertFalse(guard.inspect(m, _signAs(guard, m, badPk)));
        assertFalse(guard.paused());
    }

    function testFuzz_nonSequentialNonceRejects(uint256 nonce) public {
        nonce = bound(nonce, 2, type(uint64).max);
        SettlementMessage memory m = _msg(100 ether, nonce);
        assertFalse(guard.inspect(m, _sign(guard, m)));
        assertFalse(guard.paused());
    }

    function testFuzz_replayRejects(uint256 value) public {
        value = bound(value, MIN, MAX);
        SettlementMessage memory m = _msg(value, 1);
        assertTrue(guard.inspect(m, _sign(guard, m)));
        assertFalse(guard.inspect(m, _sign(guard, m)));
        assertFalse(guard.paused());
    }

    function testFuzz_unenrolledSourceRejects(bytes32 srcId) public {
        vm.assume(srcId != SRC);
        SettlementMessage memory m = _msg(100 ether, 1);
        m.srcId = srcId;
        assertFalse(guard.inspect(m, _sign(guard, m)));
        assertFalse(guard.paused());
    }

    function testFuzz_expiredRejects(uint256 age) public {
        vm.warp(block.timestamp + 3650 days);
        age = bound(age, 1, block.timestamp);
        SettlementMessage memory m = _msg(100 ether, 1);
        m.deadline = block.timestamp - age;
        assertFalse(guard.inspect(m, _sign(guard, m)));
        assertFalse(guard.paused());
    }
}
