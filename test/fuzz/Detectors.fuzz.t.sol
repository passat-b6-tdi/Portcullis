// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";
import { PortcullisGuard } from "../../contracts/core/PortcullisGuard.sol";
import { SettlementMessage } from "../../contracts/core/types/GuardTypes.sol";
import { MockIdentityRegistry } from "../mocks/MockIdentityRegistry.sol";

contract DetectorsFuzzTest is Test {
    PortcullisGuard internal guard;
    MockIdentityRegistry internal identity;

    address internal guardianAddr = makeAddr("guardian");
    address internal sender = makeAddr("sender");
    address internal recipient = makeAddr("recipient");
    address internal token = makeAddr("token");

    bytes32 internal constant SRC = keccak256("src");
    uint256 internal constant MIN = 1 ether;
    uint256 internal constant MAX = 1000 ether;

    function setUp() public {
        identity = new MockIdentityRegistry();
        identity.setAuthority(SRC, sender);
        guard = new PortcullisGuard(guardianAddr, guardianAddr, address(identity));
        vm.startPrank(guardianAddr);
        guard.setBounds(MIN, MAX);
        guard.setAllowedToken(token, true);
        vm.stopPrank();
    }

    function _msg(uint256 value, uint256 nonce, bytes32 id) internal view returns (SettlementMessage memory) {
        return SettlementMessage({
            srcId: SRC, sender: sender, recipient: recipient, token: token, value: value, appNonce: nonce, messageId: id
        });
    }

    function testFuzz_inRangeValuePasses(uint256 value, bytes32 id) public {
        value = bound(value, MIN, MAX);
        assertTrue(guard.inspect(_msg(value, 1, id), ""));
        assertFalse(guard.paused());
    }

    function testFuzz_belowMinTrips(uint256 value) public {
        value = bound(value, 0, MIN - 1);
        assertFalse(guard.inspect(_msg(value, 1, keccak256("m")), ""));
        assertTrue(guard.paused());
    }

    function testFuzz_aboveMaxTrips(uint256 value) public {
        value = bound(value, MAX + 1, type(uint128).max);
        assertFalse(guard.inspect(_msg(value, 1, keccak256("m")), ""));
        assertTrue(guard.paused());
    }

    function testFuzz_nonAuthoritySenderTrips(address badSender) public {
        vm.assume(badSender != sender);
        SettlementMessage memory m = _msg(100 ether, 1, keccak256("m"));
        m.sender = badSender;
        assertFalse(guard.inspect(m, ""));
        assertTrue(guard.paused());
    }

    function testFuzz_nonSequentialNonceTrips(uint256 nonce) public {
        nonce = bound(nonce, 2, type(uint64).max);
        assertFalse(guard.inspect(_msg(100 ether, nonce, keccak256("m")), ""));
        assertTrue(guard.paused());
    }

    function testFuzz_replayTrips(bytes32 id, uint256 v1, uint256 v2) public {
        v1 = bound(v1, MIN, MAX);
        v2 = bound(v2, MIN, MAX);
        assertTrue(guard.inspect(_msg(v1, 1, id), ""));
        assertFalse(guard.inspect(_msg(v2, 2, id), ""));
        assertTrue(guard.paused());
    }

    function testFuzz_unknownSourceTrips(bytes32 srcId) public {
        vm.assume(srcId != SRC);
        SettlementMessage memory m = _msg(100 ether, 1, keccak256("m"));
        m.srcId = srcId;
        assertFalse(guard.inspect(m, ""));
        assertTrue(guard.paused());
    }
}
