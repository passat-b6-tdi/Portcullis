// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";
import { CommonBase } from "forge-std/Base.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { PortcullisGuard } from "../../contracts/core/PortcullisGuard.sol";
import { SettlementMessage } from "../../contracts/core/types/GuardTypes.sol";
import { MockIdentityRegistry } from "../mocks/MockIdentityRegistry.sol";
import { AbiGuardedReceiver } from "../mocks/AbiGuardedReceiver.sol";
import { MockRelayer } from "../mocks/MockRelayer.sol";

contract ReceiverHandler is CommonBase, StdUtils {
    PortcullisGuard public immutable guard;
    AbiGuardedReceiver public immutable receiver;
    MockRelayer public immutable relayer;

    bytes32 public immutable src;
    address public immutable sender;
    address public immutable recipient;
    address public immutable token;
    uint256 public immutable minValue;
    uint256 public immutable maxValue;

    uint256 public nextNonce = 1;
    uint256 public clearedValue;

    constructor(
        PortcullisGuard guard_,
        AbiGuardedReceiver receiver_,
        MockRelayer relayer_,
        bytes32 src_,
        address sender_,
        address recipient_,
        address token_,
        uint256 minValue_,
        uint256 maxValue_
    ) {
        guard = guard_;
        receiver = receiver_;
        relayer = relayer_;
        src = src_;
        sender = sender_;
        recipient = recipient_;
        token = token_;
        minValue = minValue_;
        maxValue = maxValue_;
    }

    function _tmpl(address from, uint256 value, uint256 nonce, bytes32 id)
        internal
        view
        returns (SettlementMessage memory)
    {
        return SettlementMessage({
            srcId: src, sender: from, recipient: recipient, token: token, value: value, appNonce: nonce, messageId: id
        });
    }

    function _deliver(SettlementMessage memory m) internal {
        uint256 before = guard.lastNonce(src);
        try relayer.send(receiver, m, "") { } catch { }
        if (guard.lastNonce(src) == before + 1) clearedValue += m.value;
        nextNonce = guard.lastNonce(src) + 1;
    }

    function sendValid(uint256 valueSeed) external {
        _deliver(_tmpl(sender, bound(valueSeed, minValue, maxValue), nextNonce, keccak256(abi.encode("v", nextNonce))));
    }

    function sendSpoofed(uint256 valueSeed, address badSender) external {
        if (badSender == sender) return;
        _deliver(
            _tmpl(badSender, bound(valueSeed, minValue, maxValue), nextNonce, keccak256(abi.encode("s", nextNonce)))
        );
    }

    function sendReplay(uint256 valueSeed) external {
        _deliver(_tmpl(sender, bound(valueSeed, minValue, maxValue), nextNonce, keccak256(abi.encode("v", 1))));
    }

    function sendOversized(uint256 valueSeed) external {
        _deliver(
            _tmpl(
                sender,
                bound(valueSeed, maxValue + 1, type(uint128).max),
                nextNonce,
                keccak256(abi.encode("o", nextNonce))
            )
        );
    }
}

contract ReceiverLedgerInvariantTest is Test {
    PortcullisGuard internal guard;
    MockIdentityRegistry internal identity;
    AbiGuardedReceiver internal receiver;
    MockRelayer internal relayer;
    ReceiverHandler internal handler;

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

        receiver = new AbiGuardedReceiver(guard);
        relayer = new MockRelayer();
        handler = new ReceiverHandler(guard, receiver, relayer, SRC, sender, recipient, token, MIN, MAX);
        targetContract(address(handler));
    }

    // the adapter runs _handleValidated exactly once per guard-cleared settlement:
    // a trip or a decode failure yields zero downstream action
    function invariant_receiverSettlesExactlyWhatGuardClears() public view {
        assertEq(receiver.validatedCount(), guard.lastNonce(SRC));
    }

    function invariant_creditedEqualsClearedValue() public view {
        assertEq(receiver.credited(recipient), handler.clearedValue());
    }

    function invariant_nothingCreditedWhilePaused() public view {
        if (!guard.paused()) return;
        assertEq(receiver.validatedCount(), guard.lastNonce(SRC));
    }
}
