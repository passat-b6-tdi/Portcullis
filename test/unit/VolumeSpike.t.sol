// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { PortcullisGuard } from "../../contracts/core/PortcullisGuard.sol";
import { IVolumeVerdictOracle } from "../../contracts/core/interfaces/IVolumeVerdictOracle.sol";
import { SettlementMessage, TripReason } from "../../contracts/core/types/GuardTypes.sol";
import { MockIdentityRegistry } from "../mocks/MockIdentityRegistry.sol";
import { MockVolumeOracle } from "../mocks/MockVolumeOracle.sol";
import { GuardScenario } from "../util/GuardScenario.sol";

contract VolumeSpikeTest is GuardScenario {
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

    function test_localEma_passesDuringWarmup() public {
        vm.prank(guardianAddr);
        guard.setVolumePolicy(IVolumeVerdictOracle(address(0)), 20_000, 3);

        assertTrue(_pass(100 ether, 1));
        assertTrue(_pass(5000 ether, 2));
        assertTrue(_pass(100 ether, 3));
    }

    function test_localEma_tripsAboveThresholdAfterWarmup() public {
        vm.prank(guardianAddr);
        guard.setVolumePolicy(IVolumeVerdictOracle(address(0)), 20_000, 2);

        assertTrue(_pass(100 ether, 1));
        assertTrue(_pass(100 ether, 2));

        (uint256 baseline,) = guard.volumeStatOf(SRC);
        assertEq(baseline, 100 ether);

        SettlementMessage memory spike = _msg(201 ether, 3);
        vm.expectEmit(true, true, false, true, address(guard));
        emit SentinelTripped(TripReason.VOLUME_SPIKE, guard.digestOf(spike), address(this));
        assertFalse(guard.inspect(spike, _sign(guard, spike)));
        assertTrue(guard.paused());
    }

    function test_localEma_atThresholdPasses() public {
        vm.prank(guardianAddr);
        guard.setVolumePolicy(IVolumeVerdictOracle(address(0)), 20_000, 2);

        assertTrue(_pass(100 ether, 1));
        assertTrue(_pass(100 ether, 2));

        assertTrue(_pass(200 ether, 3));
        assertFalse(guard.paused());
    }

    function test_oracleMode_tripsOnNegativeVerdict() public {
        MockVolumeOracle oracle = new MockVolumeOracle();
        vm.prank(guardianAddr);
        guard.setVolumePolicy(oracle, 0, 0);

        assertTrue(_pass(100 ether, 1));

        oracle.setVerdict(false);
        SettlementMessage memory m = _msg(100 ether, 2);
        vm.expectEmit(true, true, false, true, address(guard));
        emit SentinelTripped(TripReason.VOLUME_SPIKE, guard.digestOf(m), address(this));
        assertFalse(guard.inspect(m, _sign(guard, m)));
    }

    function test_oracleMode_doesNotUpdateLocalBaseline() public {
        MockVolumeOracle oracle = new MockVolumeOracle();
        vm.prank(guardianAddr);
        guard.setVolumePolicy(oracle, 20_000, 2);

        assertTrue(_pass(100 ether, 1));
        assertTrue(_pass(100 ether, 2));

        (uint256 baseline, uint256 observations) = guard.volumeStatOf(SRC);
        assertEq(baseline, 0);
        assertEq(observations, 0);
    }

    function test_volumeDisabled_whenUnconfigured() public {
        assertTrue(_pass(999_999 ether, 1));
        assertFalse(guard.paused());
    }

    // F5: one source's high-value traffic must not raise another source's threshold
    function test_localEma_isPerSource() public {
        bytes32 SRC2 = keccak256("src2");
        identity.setAuthority(SRC2, authority);
        vm.startPrank(guardianAddr);
        guard.setEnrolled(SRC2, true);
        guard.setVolumePolicy(IVolumeVerdictOracle(address(0)), 20_000, 2);
        vm.stopPrank();

        // train SRC to a large baseline
        assertTrue(_pass(10_000 ether, 1));
        assertTrue(_pass(10_000 ether, 2));
        (uint256 baseSrc,) = guard.volumeStatOf(SRC);
        assertEq(baseSrc, 10_000 ether);

        // SRC2 keeps its own (zero) baseline; warmup still protects it
        (uint256 baseSrc2, uint256 obsSrc2) = guard.volumeStatOf(SRC2);
        assertEq(baseSrc2, 0);
        assertEq(obsSrc2, 0);

        // after SRC2 warms on small values, a spike relative to *its* baseline trips,
        // even though SRC's baseline would have allowed it
        SettlementMessage memory a = _msg2(SRC2, 100 ether, 1);
        assertTrue(guard.inspect(a, _sign(guard, a)));
        SettlementMessage memory b = _msg2(SRC2, 100 ether, 2);
        assertTrue(guard.inspect(b, _sign(guard, b)));

        SettlementMessage memory spike = _msg2(SRC2, 5_000 ether, 3);
        assertFalse(guard.inspect(spike, _sign(guard, spike)));
        assertTrue(guard.paused());
    }

    function _msg2(bytes32 src, uint256 value, uint256 nonce) internal view returns (SettlementMessage memory) {
        return SettlementMessage({
            srcId: src,
            recipient: recipient,
            token: token,
            value: value,
            appNonce: nonce,
            deadline: block.timestamp + 1 days
        });
    }
}
