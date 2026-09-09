// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { CommonBase } from "forge-std/Base.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { PortcullisGuard } from "../../contracts/core/PortcullisGuard.sol";
import { SettlementMessage } from "../../contracts/core/types/GuardTypes.sol";
import { MockIdentityRegistry } from "../mocks/MockIdentityRegistry.sol";
import { AbiGuardedReceiver } from "../mocks/AbiGuardedReceiver.sol";
import { MockRelayer } from "../mocks/MockRelayer.sol";
import { GuardScenario } from "../util/GuardScenario.sol";

contract ReceiverHandler is CommonBase, StdUtils {
    PortcullisGuard public immutable guard;
    AbiGuardedReceiver public immutable receiver;
    MockRelayer public immutable relayer;

    bytes32 public immutable src;
    address public immutable recipient;
    address public immutable token;
    uint256 public immutable minValue;
    uint256 public immutable maxValue;
    uint256 internal immutable authorityPk;

    uint256 public nextNonce = 1;
    uint256 public clearedValue;

    SettlementMessage internal _lastCleared;
    bool internal _haveCleared;

    constructor(
        PortcullisGuard guard_,
        AbiGuardedReceiver receiver_,
        MockRelayer relayer_,
        bytes32 src_,
        uint256 authorityPk_,
        address recipient_,
        address token_,
        uint256 minValue_,
        uint256 maxValue_
    ) {
        guard = guard_;
        receiver = receiver_;
        relayer = relayer_;
        src = src_;
        authorityPk = authorityPk_;
        recipient = recipient_;
        token = token_;
        minValue = minValue_;
        maxValue = maxValue_;
    }

    function _tmpl(uint256 value, uint256 nonce) internal view returns (SettlementMessage memory) {
        return SettlementMessage({
            srcId: src,
            recipient: recipient,
            token: token,
            value: value,
            appNonce: nonce,
            deadline: block.timestamp + 365 days
        });
    }

    function _sign(SettlementMessage memory m, uint256 pk) internal view returns (bytes memory) {
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", guard.digestOf(m)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, ethHash);
        return abi.encodePacked(r, s, v);
    }

    function _deliver(SettlementMessage memory m, bytes memory proof) internal {
        uint256 before = guard.lastNonce(src);
        try relayer.send(receiver, m, proof) { } catch { }
        if (guard.lastNonce(src) == before + 1) {
            clearedValue += m.value;
            _lastCleared = m;
            _haveCleared = true;
        }
        nextNonce = guard.lastNonce(src) + 1;
    }

    function sendValid(uint256 valueSeed) external {
        SettlementMessage memory m = _tmpl(bound(valueSeed, minValue, maxValue), nextNonce);
        _deliver(m, _sign(m, authorityPk));
    }

    function sendBadSignature(uint256 valueSeed) external {
        SettlementMessage memory m = _tmpl(bound(valueSeed, minValue, maxValue), nextNonce);
        _deliver(m, _sign(m, authorityPk + 1));
    }

    function sendReplay() external {
        if (!_haveCleared) return;
        SettlementMessage memory m = _lastCleared;
        _deliver(m, _sign(m, authorityPk));
    }

    function sendOversized(uint256 valueSeed) external {
        SettlementMessage memory m = _tmpl(bound(valueSeed, maxValue + 1, type(uint128).max), nextNonce);
        _deliver(m, _sign(m, authorityPk));
    }
}

contract ReceiverLedgerInvariantTest is GuardScenario {
    PortcullisGuard internal guard;
    MockIdentityRegistry internal identity;
    AbiGuardedReceiver internal receiver;
    MockRelayer internal relayer;
    ReceiverHandler internal handler;

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

        receiver = new AbiGuardedReceiver(guard);
        relayer = new MockRelayer();
        handler = new ReceiverHandler(guard, receiver, relayer, SRC, AUTHORITY_PK, recipient, token, MIN, MAX);

        vm.startPrank(guardianAddr);
        guard.setBounds(MIN, MAX);
        guard.setAllowedToken(token, true, 18);
        guard.setEnrolled(SRC, true);
        guard.setAdapter(address(receiver), true);
        vm.stopPrank();

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
