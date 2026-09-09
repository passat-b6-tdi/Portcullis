// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";
import { PortcullisGuard } from "../../contracts/core/PortcullisGuard.sol";
import { IVolumeVerdictOracle } from "../../contracts/core/interfaces/IVolumeVerdictOracle.sol";
import { SettlementMessage, TripReason } from "../../contracts/core/types/GuardTypes.sol";
import { MockIdentityRegistry } from "../mocks/MockIdentityRegistry.sol";
import { MockVolumeOracle } from "../mocks/MockVolumeOracle.sol";

contract VolumeSpikeTest is Test {
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
        guard = new PortcullisGuard(guardianAddr, guardianAddr, address(identity));

        vm.startPrank(guardianAddr);
        guard.setBounds(1, 1_000_000 ether);
        guard.setAllowedToken(token, true);
        vm.stopPrank();
    }

    function _msg(uint256 value, uint256 nonce, bytes32 id) internal view returns (SettlementMessage memory) {
        return SettlementMessage({
            srcId: SRC, sender: sender, recipient: recipient, token: token, value: value, appNonce: nonce, messageId: id
        });
    }

    function test_localEma_passesDuringWarmup() public {
        vm.prank(guardianAddr);
        guard.setVolumePolicy(IVolumeVerdictOracle(address(0)), 20_000, 3);

        assertTrue(guard.inspect(_msg(100 ether, 1, keccak256("a")), ""));
        assertTrue(guard.inspect(_msg(5000 ether, 2, keccak256("b")), ""));
        assertTrue(guard.inspect(_msg(100 ether, 3, keccak256("c")), ""));
    }

    function test_localEma_tripsAboveThresholdAfterWarmup() public {
        vm.prank(guardianAddr);
        guard.setVolumePolicy(IVolumeVerdictOracle(address(0)), 20_000, 2);

        assertTrue(guard.inspect(_msg(100 ether, 1, keccak256("a")), ""));
        assertTrue(guard.inspect(_msg(100 ether, 2, keccak256("b")), ""));

        (, uint256 baseline,,,) = guard.volumeState();
        assertEq(baseline, 100 ether);

        SettlementMessage memory spike = _msg(201 ether, 3, keccak256("c"));
        vm.expectEmit(true, true, false, true, address(guard));
        emit SentinelTripped(TripReason.VOLUME_SPIKE, spike.messageId, address(this));
        assertFalse(guard.inspect(spike, ""));
        assertTrue(guard.paused());
    }

    function test_localEma_atThresholdPasses() public {
        vm.prank(guardianAddr);
        guard.setVolumePolicy(IVolumeVerdictOracle(address(0)), 20_000, 2);

        assertTrue(guard.inspect(_msg(100 ether, 1, keccak256("a")), ""));
        assertTrue(guard.inspect(_msg(100 ether, 2, keccak256("b")), ""));

        assertTrue(guard.inspect(_msg(200 ether, 3, keccak256("c")), ""));
        assertFalse(guard.paused());
    }

    function test_oracleMode_tripsOnNegativeVerdict() public {
        MockVolumeOracle oracle = new MockVolumeOracle();
        vm.prank(guardianAddr);
        guard.setVolumePolicy(oracle, 0, 0);

        assertTrue(guard.inspect(_msg(100 ether, 1, keccak256("a")), ""));

        oracle.setVerdict(false);
        SettlementMessage memory m = _msg(100 ether, 2, keccak256("b"));
        vm.expectEmit(true, true, false, true, address(guard));
        emit SentinelTripped(TripReason.VOLUME_SPIKE, m.messageId, address(this));
        assertFalse(guard.inspect(m, ""));
    }

    function test_oracleMode_doesNotUpdateLocalBaseline() public {
        MockVolumeOracle oracle = new MockVolumeOracle();
        vm.prank(guardianAddr);
        guard.setVolumePolicy(oracle, 20_000, 2);

        assertTrue(guard.inspect(_msg(100 ether, 1, keccak256("a")), ""));
        assertTrue(guard.inspect(_msg(100 ether, 2, keccak256("b")), ""));

        (, uint256 baseline,, uint256 observations,) = guard.volumeState();
        assertEq(baseline, 0);
        assertEq(observations, 0);
    }

    function test_volumeDisabled_whenUnconfigured() public {
        assertTrue(guard.inspect(_msg(999_999 ether, 1, keccak256("a")), ""));
        assertFalse(guard.paused());
    }
}
