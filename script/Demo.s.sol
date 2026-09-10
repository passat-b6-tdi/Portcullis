// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Script, console2 } from "forge-std/Script.sol";
import { PortcullisGuard } from "../contracts/core/PortcullisGuard.sol";
import { AddressBookRegistry } from "../contracts/identity/AddressBookRegistry.sol";
import { ArcSettlementReceiver } from "../contracts/adapters/ArcSettlementReceiver.sol";
import { IVolumeVerdictOracle } from "../contracts/core/interfaces/IVolumeVerdictOracle.sol";
import { SettlementMessage } from "../contracts/core/types/GuardTypes.sol";
import { MockERC20 } from "../test/mocks/MockERC20.sol";

contract Demo is Script {
    bytes32 constant SRC = keccak256("treasury.acme.portcullis.eth");

    PortcullisGuard guard;
    AddressBookRegistry registry;
    ArcSettlementReceiver receiver;
    MockERC20 usdc;

    uint256 deskPk = 2;

    address deployer = vm.addr(1);
    address desk = vm.addr(2); // the enrolled source authority
    address counterparty = vm.addr(3);
    address attacker = vm.addr(4);

    function run() external {
        _deploy();
        _happyPath();
        _forgedRejected();
        _anomalyTrips();
        _guardianRecovers();
        console2.log("");
        console2.log("demo complete");
    }

    function _deploy() internal {
        vm.startPrank(deployer);
        registry = new AddressBookRegistry(deployer);
        registry.setAuthority(SRC, desk);

        guard = new PortcullisGuard(deployer, deployer, address(registry));
        usdc = new MockERC20("USD Coin", "USDC", 6);

        guard.setBounds(1e18, 5_000_000e18); // 18-dec normalised
        guard.setAllowedToken(address(usdc), true, 6);
        guard.setVolumePolicy(IVolumeVerdictOracle(address(0)), 30_000, 2);
        guard.setEnrolled(SRC, true);

        receiver = new ArcSettlementReceiver(guard);
        guard.setAdapter(address(receiver), true);
        usdc.mint(address(receiver), 20_000_000e6);
        vm.stopPrank();

        console2.log("guard      ", address(guard));
        console2.log("receiver   ", address(receiver));
        console2.log("authority  ", desk);
    }

    function _msg(address to, uint256 value, uint256 nonce) internal view returns (SettlementMessage memory) {
        return SettlementMessage({
            srcId: SRC,
            recipient: to,
            token: address(usdc),
            value: value,
            appNonce: nonce,
            deadline: block.timestamp + 1 days
        });
    }

    function _deliver(SettlementMessage memory m, uint256 signerPk) internal {
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", guard.digestOf(m)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, ethHash);
        receiver.receiveMessage(abi.encode(m, abi.encodePacked(r, s, v)));
    }

    function _happyPath() internal {
        console2.log("");
        console2.log("1. settlement, signed by the desk authority");
        _deliver(_msg(counterparty, 100_000e6, 1), deskPk);
        _deliver(_msg(counterparty, 100_000e6, 2), deskPk);
        console2.log("   counterparty USDC:", usdc.balanceOf(counterparty));
        console2.log("   guard paused:     ", guard.paused());
    }

    function _forgedRejected() internal {
        console2.log("");
        console2.log("2. forged message: attacker signs with its own key -> rejected, breaker stays up");
        _deliver(_msg(attacker, 100_000e6, 3), 4);
        console2.log("   attacker USDC:", usdc.balanceOf(attacker));
        console2.log("   guard paused: ", guard.paused());
    }

    function _anomalyTrips() internal {
        console2.log("");
        console2.log("3. authenticated anomaly: desk-signed value far above baseline -> VOLUME_SPIKE latch");
        _deliver(_msg(counterparty, 4_000_000e6, 3), deskPk);
        console2.log("   counterparty USDC:", usdc.balanceOf(counterparty));
        console2.log("   guard paused:     ", guard.paused());
    }

    function _guardianRecovers() internal {
        console2.log("");
        console2.log("4. guardian clears the breaker, genuine flow resumes");
        vm.prank(deployer);
        guard.clear();
        _deliver(_msg(counterparty, 100_000e6, 3), deskPk);
        console2.log("   counterparty USDC:", usdc.balanceOf(counterparty));
        console2.log("   guard paused:     ", guard.paused());
    }
}
