// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";
import { AddressHelper } from "../../contracts/AddressHelper.sol";
import { CrePolicyConsumer } from "../../contracts/oracle/CrePolicyConsumer.sol";

contract CrePolicyConsumerTest is Test {
    uint8 internal constant ALLOW = 0;
    uint8 internal constant DENY = 2;

    CrePolicyConsumer internal consumer;
    uint256 internal signerKey;
    address internal signerAddr;
    uint256 internal wrongKey;

    bytes32 internal constant MSG_HASH = keccak256("settlement");

    function setUp() public {
        signerKey = 0xA11CE;
        signerAddr = vm.addr(signerKey);
        wrongKey = 0xB0B;
        consumer = new CrePolicyConsumer(signerAddr);
    }

    function _attest(uint8 verdict, uint8 riskMask, uint64 issuedAt, uint256 key) internal view returns (bytes memory) {
        bytes32 digest = ECDSA.toEthSignedMessageHash(keccak256(abi.encode(MSG_HASH, verdict, riskMask, issuedAt)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encode(verdict, riskMask, issuedAt, abi.encodePacked(r, s, v));
    }

    function test_constructor_rejectsZeroSigner() public {
        vm.expectRevert(AddressHelper.ZeroAddress.selector);
        new CrePolicyConsumer(address(0));
    }

    function test_validAllow_isReturned() public view {
        bytes memory att = _attest(ALLOW, 0x00, uint64(block.timestamp), signerKey);
        (uint8 verdict, uint8 riskMask) = consumer.evaluate(MSG_HASH, att);
        assertEq(verdict, ALLOW);
        assertEq(riskMask, 0x00);
    }

    function test_validDeny_isReturned() public view {
        bytes memory att = _attest(DENY, 0x0F, uint64(block.timestamp), signerKey);
        (uint8 verdict, uint8 riskMask) = consumer.evaluate(MSG_HASH, att);
        assertEq(verdict, DENY);
        assertEq(riskMask, 0x0F);
    }

    function test_emptyAttestation_denies() public view {
        (uint8 verdict,) = consumer.evaluate(MSG_HASH, "");
        assertEq(verdict, DENY);
    }

    function test_wrongSigner_denies() public view {
        bytes memory att = _attest(ALLOW, 0x00, uint64(block.timestamp), wrongKey);
        (uint8 verdict,) = consumer.evaluate(MSG_HASH, att);
        assertEq(verdict, DENY);
    }

    function test_staleAttestation_denies() public {
        bytes memory att = _attest(ALLOW, 0x00, uint64(block.timestamp), signerKey);
        vm.warp(block.timestamp + consumer.MAX_AGE() + 1);
        (uint8 verdict,) = consumer.evaluate(MSG_HASH, att);
        assertEq(verdict, DENY);
    }

    function test_tamperedRiskMask_denies() public view {
        bytes memory att = _attest(ALLOW, 0x00, uint64(block.timestamp), signerKey);
        (uint8 v, uint8 r, uint64 t, bytes memory sig) = abi.decode(att, (uint8, uint8, uint64, bytes));
        bytes memory tampered = abi.encode(v, uint8(0xFF), t, sig);
        (uint8 verdict,) = consumer.evaluate(MSG_HASH, tampered);
        assertEq(verdict, DENY);
    }

    function test_wrongMsgHash_denies() public view {
        bytes memory att = _attest(ALLOW, 0x00, uint64(block.timestamp), signerKey);
        (uint8 verdict,) = consumer.evaluate(keccak256("other"), att);
        assertEq(verdict, DENY);
    }
}
