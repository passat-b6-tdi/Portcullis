// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";
import { Ownable } from "solady/auth/Ownable.sol";
import { AddressHelper } from "../../contracts/AddressHelper.sol";
import { CrePolicyConsumer } from "../../contracts/oracle/CrePolicyConsumer.sol";
import { ReceiverTemplate } from "../../contracts/oracle/ReceiverTemplate.sol";

contract CrePolicyConsumerTest is Test {
    uint8 internal constant ALLOW = 1;
    uint8 internal constant DENY = 2;
    uint8 internal constant REVIEW = 3;

    CrePolicyConsumer internal consumer;
    address internal forwarder = makeAddr("forwarder");
    address internal owner = makeAddr("owner");
    address internal stranger = makeAddr("stranger");

    bytes32 internal constant MSG_HASH = keccak256("settlement");

    event VerdictStored(bytes32 indexed msgHash, uint8 code, uint8 riskMask, uint64 issuedAt);

    function setUp() public {
        consumer = new CrePolicyConsumer(forwarder, owner);
    }

    function _report(bytes32 msgHash, uint8 code, uint8 riskMask, uint64 issuedAt) internal {
        vm.prank(forwarder);
        consumer.onReport("", abi.encode(msgHash, code, riskMask, issuedAt));
    }

    function test_constructor_rejectsZeroForwarder() public {
        vm.expectRevert(ReceiverTemplate.InvalidForwarder.selector);
        new CrePolicyConsumer(address(0), owner);
    }

    function test_constructor_rejectsZeroOwner() public {
        vm.expectRevert(AddressHelper.ZeroAddress.selector);
        new CrePolicyConsumer(forwarder, address(0));
    }

    function test_onReport_onlyForwarder() public {
        vm.prank(stranger);
        vm.expectRevert(ReceiverTemplate.InvalidSender.selector);
        consumer.onReport("", abi.encode(MSG_HASH, ALLOW, uint8(0), uint64(block.timestamp)));
    }

    function test_storesAndReturnsAllow() public {
        vm.expectEmit(true, false, false, true, address(consumer));
        emit VerdictStored(MSG_HASH, ALLOW, 0x00, uint64(block.timestamp));
        _report(MSG_HASH, ALLOW, 0x00, uint64(block.timestamp));

        (uint8 verdict, uint8 riskMask) = consumer.evaluate(MSG_HASH, "");
        assertEq(verdict, ALLOW);
        assertEq(riskMask, 0x00);
    }

    function test_storesAndReturnsDeny() public {
        _report(MSG_HASH, DENY, 0x0F, uint64(block.timestamp));
        (uint8 verdict, uint8 riskMask) = consumer.evaluate(MSG_HASH, "");
        assertEq(verdict, DENY);
        assertEq(riskMask, 0x0F);
    }

    function test_unknownMessage_denies() public view {
        (uint8 verdict,) = consumer.evaluate(keccak256("never-cleared"), "");
        assertEq(verdict, DENY);
    }

    function test_staleVerdict_denies() public {
        _report(MSG_HASH, ALLOW, 0x00, uint64(block.timestamp));
        vm.warp(block.timestamp + consumer.maxAge() + 1);
        (uint8 verdict,) = consumer.evaluate(MSG_HASH, "");
        assertEq(verdict, DENY);
    }

    function test_freshWithinMaxAge_returnsStored() public {
        _report(MSG_HASH, ALLOW, 0x00, uint64(block.timestamp));
        vm.warp(block.timestamp + consumer.maxAge() - 1);
        (uint8 verdict,) = consumer.evaluate(MSG_HASH, "");
        assertEq(verdict, ALLOW);
    }

    function test_latestReportWins() public {
        _report(MSG_HASH, ALLOW, 0x00, uint64(block.timestamp));
        _report(MSG_HASH, REVIEW, 0x04, uint64(block.timestamp));
        (uint8 verdict, uint8 riskMask) = consumer.evaluate(MSG_HASH, "");
        assertEq(verdict, REVIEW);
        assertEq(riskMask, 0x04);
    }

    function test_setMaxAge_onlyOwner() public {
        vm.prank(stranger);
        vm.expectRevert(Ownable.Unauthorized.selector);
        consumer.setMaxAge(1 days);

        vm.prank(owner);
        consumer.setMaxAge(1 days);
        assertEq(consumer.maxAge(), 1 days);
    }

    function test_setForwarder_onlyOwner() public {
        address newForwarder = makeAddr("newForwarder");

        vm.prank(stranger);
        vm.expectRevert(Ownable.Unauthorized.selector);
        consumer.setForwarderAddress(newForwarder);

        vm.prank(owner);
        consumer.setForwarderAddress(newForwarder);
        assertEq(consumer.getForwarderAddress(), newForwarder);
    }

    function test_renounceOwnership_blocked() public {
        vm.prank(owner);
        vm.expectRevert();
        consumer.renounceOwnership();
    }
}
