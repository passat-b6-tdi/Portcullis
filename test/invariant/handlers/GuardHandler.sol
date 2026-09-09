// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { CommonBase } from "forge-std/Base.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { PortcullisGuard } from "../../../contracts/core/PortcullisGuard.sol";
import { SettlementMessage } from "../../../contracts/core/types/GuardTypes.sol";

// Drives the guard with a mix of authenticated and hostile messages. No clear()
// action: once tripped the guard stays tripped, so post-trip invariants are
// unambiguous. Only rate/volume anomalies latch; forged and malformed messages
// are rejected without pausing.
contract GuardHandler is CommonBase, StdUtils {
    PortcullisGuard public immutable guard;
    bytes32 public immutable src;
    address public immutable recipient;
    address public immutable token;
    uint256 public immutable minValue;
    uint256 public immutable maxValue;
    uint256 internal immutable authorityPk;

    uint256 public nextNonce = 1;
    bytes32[] public settledIds;
    mapping(bytes32 => uint256) public settledCount;
    uint256 public totalCleared;

    SettlementMessage internal _lastCleared;
    bool internal _haveCleared;

    bool public everPaused;
    uint256 public frozenNonce;
    uint256 public frozenCleared;

    constructor(
        PortcullisGuard guard_,
        bytes32 src_,
        uint256 authorityPk_,
        address recipient_,
        address token_,
        uint256 minValue_,
        uint256 maxValue_
    ) {
        guard = guard_;
        src = src_;
        authorityPk = authorityPk_;
        recipient = recipient_;
        token = token_;
        minValue = minValue_;
        maxValue = maxValue_;
    }

    function _template(uint256 value, uint256 nonce) internal view returns (SettlementMessage memory) {
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

    function _send(SettlementMessage memory m, bytes memory proof, bool countable) internal {
        try guard.inspect(m, proof) returns (bool ok) {
            if (ok && countable) {
                bytes32 id = guard.digestOf(m);
                nextNonce++;
                settledIds.push(id);
                settledCount[id]++;
                totalCleared += m.value;
                _lastCleared = m;
                _haveCleared = true;
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
        SettlementMessage memory m = _template(value, nextNonce);
        _send(m, _sign(m, authorityPk), true);
    }

    function sendReplay() external {
        if (!_haveCleared) return;
        SettlementMessage memory m = _lastCleared;
        _send(m, _sign(m, authorityPk), false);
    }

    function sendBadSignature(uint256 valueSeed) external {
        SettlementMessage memory m = _template(bound(valueSeed, minValue, maxValue), nextNonce);
        _send(m, _sign(m, authorityPk + 1), false);
    }

    function sendOversized(uint256 valueSeed) external {
        SettlementMessage memory m = _template(bound(valueSeed, maxValue + 1, type(uint128).max), nextNonce);
        _send(m, _sign(m, authorityPk), false);
    }

    function sendNonceSkip(uint256 gapSeed) external {
        uint256 gap = bound(gapSeed, 2, 1_000);
        SettlementMessage memory m = _template(minValue, nextNonce + gap);
        _send(m, _sign(m, authorityPk), false);
    }

    function warp(uint256 secondsSeed) external {
        vm.warp(block.timestamp + bound(secondsSeed, 1, 30 days));
    }

    function settledCountLength() external view returns (uint256) {
        return settledIds.length;
    }
}
