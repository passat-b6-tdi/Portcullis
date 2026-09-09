// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { PortcullisGuard } from "../../contracts/core/PortcullisGuard.sol";
import { ArcSettlementReceiver } from "../../contracts/adapters/ArcSettlementReceiver.sol";
import { SettlementMessage } from "../../contracts/core/types/GuardTypes.sol";
import { AddressBookRegistry } from "../../contracts/identity/AddressBookRegistry.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";
import { MockRelayer } from "../mocks/MockRelayer.sol";
import { GuardScenario } from "../util/GuardScenario.sol";

contract ArcSettlementReceiverTest is GuardScenario {
    PortcullisGuard internal guard;
    AddressBookRegistry internal registry;
    ArcSettlementReceiver internal receiver;
    MockRelayer internal relayer;
    MockERC20 internal usdc;

    address internal guardianAddr = makeAddr("guardian");
    address internal recipient = makeAddr("recipient");

    bytes32 internal constant SRC = keccak256("acme.portcullis.eth");

    event SettlementPaid(bytes32 indexed messageId, address indexed recipient, address token, uint256 value);
    event SettlementRejected(bytes32 indexed messageId);

    function setUp() public {
        registry = new AddressBookRegistry(address(this));
        registry.setAuthority(SRC, authority);

        guard = new PortcullisGuard(guardianAddr, guardianAddr, address(registry));
        usdc = new MockERC20("USD Coin", "USDC", 6);

        receiver = new ArcSettlementReceiver(guard);
        relayer = new MockRelayer();
        usdc.mint(address(receiver), 1_000_000e6);

        vm.startPrank(guardianAddr);
        guard.setBounds(1e18, 5_000_000e18); // 18-dec normalised
        guard.setAllowedToken(address(usdc), true, 6);
        guard.setEnrolled(SRC, true);
        guard.setAdapter(address(receiver), true);
        vm.stopPrank();
    }

    function _msg(uint256 value, uint256 nonce) internal view returns (SettlementMessage memory) {
        return SettlementMessage({
            srcId: SRC,
            recipient: recipient,
            token: address(usdc),
            value: value,
            appNonce: nonce,
            deadline: block.timestamp + 1 days
        });
    }

    function _deliver(uint256 value, uint256 nonce) internal {
        SettlementMessage memory m = _msg(value, nonce);
        relayer.send(receiver, m, _sign(guard, m));
    }

    function test_clearedSettlement_paysRecipient() public {
        SettlementMessage memory m = _msg(250_000e6, 1);

        vm.expectEmit(true, true, false, true, address(receiver));
        emit SettlementPaid(guard.digestOf(m), recipient, address(usdc), 250_000e6);

        relayer.send(receiver, m, _sign(guard, m));

        assertEq(usdc.balanceOf(recipient), 250_000e6);
        assertEq(usdc.balanceOf(address(receiver)), 750_000e6);
        assertFalse(guard.paused());
    }

    function test_unauthenticatedSettlement_notPaid_notLatched() public {
        SettlementMessage memory m = _msg(100e6, 1);

        vm.expectEmit(true, false, false, false, address(receiver));
        emit SettlementRejected(guard.digestOf(m));

        relayer.send(receiver, m, _signAs(guard, m, 0xBEEF));

        assertEq(usdc.balanceOf(recipient), 0);
        assertFalse(guard.paused());
    }

    function test_insufficientFloat_reverts_andNoLedgerMutation() public {
        SettlementMessage memory m = _msg(2_000_000e6, 1);
        vm.expectRevert();
        relayer.send(receiver, m, _sign(guard, m));

        assertEq(guard.lastNonce(SRC), 0);
        assertFalse(guard.seen(guard.digestOf(m)));
    }

    function test_sequentialSettlements() public {
        _deliver(10e6, 1);
        _deliver(20e6, 2);
        assertEq(usdc.balanceOf(recipient), 30e6);
        assertEq(guard.lastNonce(SRC), 2);
    }
}
