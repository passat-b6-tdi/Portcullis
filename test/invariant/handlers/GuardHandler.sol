// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { CommonBase } from "forge-std/Base.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { PortcullisGuard } from "../../../contracts/core/PortcullisGuard.sol";
import { SettlementMessage } from "../../../contracts/core/types/GuardTypes.sol";

// Drives the guard with a mix of valid and hostile messages. No clear() action:
// once tripped the guard stays tripped, so post-trip invariants are unambiguous.
contract GuardHandler is CommonBase, StdUtils {
    PortcullisGuard public immutable guard;
    bytes32 public immutable src;
    address public immutable sender;
    address public immutable recipient;
    address public immutable token;
    uint256 public immutable minValue;
    uint256 public immutable maxValue;

    uint256 public nextNonce = 1;
    bytes32[] public settledIds;
    mapping(bytes32 => uint256) public settledCount;
    uint256 public totalCleared;

    bool public everPaused;
    uint256 public frozenNonce;
    uint256 public frozenCleared;

    constructor(
        PortcullisGuard guard_,
        bytes32 src_,
        address sender_,
        address recipient_,
        address token_,
        uint256 minValue_,
        uint256 maxValue_
    ) {
        guard = guard_;
        src = src_;
        sender = sender_;
        recipient = recipient_;
        token = token_;
        minValue = minValue_;
        maxValue = maxValue_;
    }

    function _template(uint256 value, uint256 nonce, bytes32 id) internal view returns (SettlementMessage memory) {
        return SettlementMessage({
            srcId: src, sender: sender, recipient: recipient, token: token, value: value, appNonce: nonce, messageId: id
        });
    }

    function _send(SettlementMessage memory m, bool countable) internal {
        try guard.inspect(m, "") returns (bool ok) {
            if (ok && countable) {
                nextNonce++;
                settledIds.push(m.messageId);
                settledCount[m.messageId]++;
                totalCleared += m.value;
            }
        } catch { }
        if (guard.paused() && !everPaused) {
            everPaused = true;
            frozenNonce = guard.lastNonce(src);
            frozenCleared = totalCleared;
        }
    }

    function sendValid(uint256 valueSeed) external {
        uint256 value = bound(valueSeed, minValue, maxValue);
        _send(_template(value, nextNonce, keccak256(abi.encode("v", nextNonce))), true);
    }

    function sendReplay(uint256 idxSeed) external {
        if (settledIds.length == 0) return;
        bytes32 id = settledIds[bound(idxSeed, 0, settledIds.length - 1)];
        _send(_template(minValue, nextNonce, id), false);
    }

    function sendBadSender(uint256 valueSeed, address badSender) external {
        if (badSender == sender) return;
        SettlementMessage memory m =
            _template(bound(valueSeed, minValue, maxValue), nextNonce, keccak256(abi.encode("b", nextNonce)));
        m.sender = badSender;
        _send(m, false);
    }

    function sendOversized(uint256 valueSeed) external {
        uint256 value = bound(valueSeed, maxValue + 1, type(uint128).max);
        _send(_template(value, nextNonce, keccak256(abi.encode("o", nextNonce))), false);
    }

    function sendNonceSkip(uint256 gapSeed) external {
        uint256 gap = bound(gapSeed, 2, 1_000);
        _send(_template(minValue, nextNonce + gap, keccak256(abi.encode("n", nextNonce))), false);
    }

    function warp(uint256 secondsSeed) external {
        vm.warp(block.timestamp + bound(secondsSeed, 1, 30 days));
    }

    function settledCountLength() external view returns (uint256) {
        return settledIds.length;
    }
}
