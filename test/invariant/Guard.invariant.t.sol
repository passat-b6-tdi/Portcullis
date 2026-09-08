// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Test } from "forge-std/Test.sol";
import { PortcullisGuard } from "../../contracts/core/PortcullisGuard.sol";
import { MockIdentityRegistry } from "../mocks/MockIdentityRegistry.sol";
import { GuardHandler } from "./handlers/GuardHandler.sol";

contract GuardInvariantTest is Test {
    PortcullisGuard internal guard;
    MockIdentityRegistry internal identity;
    GuardHandler internal handler;

    address internal guardianAddr = makeAddr("guardian");
    address internal sender = makeAddr("sender");
    address internal recipient = makeAddr("recipient");
    address internal token = makeAddr("token");

    bytes32 internal constant SRC = keccak256("src");
    uint256 internal constant MIN = 1 ether;
    uint256 internal constant MAX = 1000 ether;
    uint256 internal constant RATE_CAPACITY = 100_000 ether;

    function setUp() public {
        identity = new MockIdentityRegistry();
        identity.setAuthority(SRC, sender);
        guard = new PortcullisGuard(guardianAddr, identity);

        vm.startPrank(guardianAddr);
        guard.setBounds(MIN, MAX);
        guard.setAllowedToken(token, true);
        guard.setRate(RATE_CAPACITY, 0); // no refill: cleared value must stay <= capacity
        vm.stopPrank();

        handler = new GuardHandler(guard, SRC, sender, recipient, token, MIN, MAX);
        targetContract(address(handler));
    }

    // guard state must not advance once the breaker has tripped
    function invariant_pausedImpliesFrozenLedger() public view {
        if (!handler.everPaused()) return;
        assertEq(guard.lastNonce(SRC), handler.frozenNonce());
        assertEq(handler.totalCleared(), handler.frozenCleared());
    }

    // no messageId is cleared twice
    function invariant_noMessageIdSettledTwice() public view {
        uint256 n = handler.settledCountLength();
        for (uint256 i = 0; i < n; i++) {
            assertEq(handler.settledCount(handler.settledIds(i)), 1);
        }
    }

    // total value cleared never exceeds the rate bucket (refill disabled here)
    function invariant_cumulativeValueWithinCapacity() public view {
        assertLe(handler.totalCleared(), RATE_CAPACITY);
    }

    // accepted count and last nonce stay consistent
    function invariant_nonceMatchesSettledCount() public view {
        assertEq(guard.lastNonce(SRC), handler.settledCountLength());
    }
}
