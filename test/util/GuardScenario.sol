// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";
import { PortcullisGuard } from "../../contracts/core/PortcullisGuard.sol";
import { SettlementMessage } from "../../contracts/core/types/GuardTypes.sol";

// Shared plumbing for guard tests: a known authority keypair and a signer that
// produces the exact `proof` bytes PortcullisChecks.evaluate expects
// (authority's ECDSA signature over the eth-signed guard digest). The digest is
// recomputed locally rather than via guard.digestOf() so it never consumes a
// pending vm.prank / vm.expectRevert / vm.expectEmit cheatcode.
abstract contract GuardScenario is Test {
    uint256 internal constant AUTHORITY_PK = 0xA11CE;
    address internal authority = vm.addr(AUTHORITY_PK);

    function _digest(PortcullisGuard guard, SettlementMessage memory m) internal view returns (bytes32) {
        return keccak256(abi.encode(block.chainid, address(guard), m));
    }

    function _sign(PortcullisGuard guard, SettlementMessage memory m) internal view returns (bytes memory) {
        return _signAs(guard, m, AUTHORITY_PK);
    }

    function _signAs(PortcullisGuard guard, SettlementMessage memory m, uint256 pk)
        internal
        view
        returns (bytes memory)
    {
        bytes32 ethHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _digest(guard, m)));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, ethHash);
        return abi.encodePacked(r, s, v);
    }
}
