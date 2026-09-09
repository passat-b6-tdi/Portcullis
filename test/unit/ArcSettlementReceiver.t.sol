// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";
import { PortcullisGuard } from "../../contracts/core/PortcullisGuard.sol";
import { ArcSettlementReceiver } from "../../contracts/adapters/ArcSettlementReceiver.sol";
import { SettlementMessage } from "../../contracts/core/types/GuardTypes.sol";
import { AddressBookRegistry } from "../../contracts/identity/AddressBookRegistry.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";
import { MockRelayer } from "../mocks/MockRelayer.sol";

contract ArcSettlementReceiverTest is Test {
    PortcullisGuard internal guard;
    AddressBookRegistry internal registry;
    ArcSettlementReceiver internal receiver;
    MockRelayer internal relayer;
    MockERC20 internal usdc;

    address internal guardianAddr = makeAddr("guardian");
    address internal sender = makeAddr("sender");
    address internal recipient = makeAddr("recipient");
    address internal attacker = makeAddr("attacker");

    bytes32 internal constant SRC = keccak256("acme.portcullis.eth");

    event SettlementPaid(bytes32 indexed messageId, address indexed recipient, address token, uint256 value);
    event SettlementRejected(bytes32 indexed messageId);

    function setUp() public {
        registry = new AddressBookRegistry(address(this));
        registry.setAuthority(SRC, sender);

        guard = new PortcullisGuard(guardianAddr, guardianAddr, address(registry));
        usdc = new MockERC20("USD Coin", "USDC", 6);

        vm.startPrank(guardianAddr);
        guard.setBounds(1e6, 5_000_000e6);
        guard.setAllowedToken(address(usdc), true);
        vm.stopPrank();

        receiver = new ArcSettlementReceiver(guard);
        relayer = new MockRelayer();
        usdc.mint(address(receiver), 1_000_000e6);
    }

    function _msg(uint256 value, uint256 nonce, bytes32 id) internal view returns (SettlementMessage memory) {
        return SettlementMessage({
            srcId: SRC,
            sender: sender,
            recipient: recipient,
            token: address(usdc),
            value: value,
            appNonce: nonce,
            messageId: id
        });
    }

    function test_clearedSettlement_paysRecipient() public {
        vm.expectEmit(true, true, false, true, address(receiver));
        emit SettlementPaid(keccak256("s1"), recipient, address(usdc), 250_000e6);

        relayer.send(receiver, _msg(250_000e6, 1, keccak256("s1")), "");

        assertEq(usdc.balanceOf(recipient), 250_000e6);
        assertEq(usdc.balanceOf(address(receiver)), 750_000e6);
        assertFalse(guard.paused());
    }

    function test_hostileSettlement_notPaid_andTrips() public {
        SettlementMessage memory m = _msg(100e6, 1, keccak256("s1"));
        m.sender = attacker;

        vm.expectEmit(true, false, false, false, address(receiver));
        emit SettlementRejected(m.messageId);

        relayer.send(receiver, m, "");

        assertEq(usdc.balanceOf(recipient), 0);
        assertTrue(guard.paused());
    }

    function test_insufficientFloat_reverts_andNoLedgerMutation() public {
        vm.expectRevert();
        relayer.send(receiver, _msg(2_000_000e6, 1, keccak256("s1")), "");

        assertEq(guard.lastNonce(SRC), 0);
        assertFalse(guard.seen(keccak256("s1")));
    }

    function test_sequentialSettlements() public {
        relayer.send(receiver, _msg(10e6, 1, keccak256("a")), "");
        relayer.send(receiver, _msg(20e6, 2, keccak256("b")), "");
        assertEq(usdc.balanceOf(recipient), 30e6);
        assertEq(guard.lastNonce(SRC), 2);
    }
}
