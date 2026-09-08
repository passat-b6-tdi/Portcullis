// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IPreSettlementPolicy } from "../../contracts/core/interfaces/IPreSettlementPolicy.sol";

contract MockPolicyOracle is IPreSettlementPolicy {
    uint8 public verdict;
    uint8 public riskMask;

    function set(uint8 verdict_, uint8 riskMask_) external {
        verdict = verdict_;
        riskMask = riskMask_;
    }

    function evaluate(bytes32, bytes calldata) external view returns (uint8, uint8) {
        return (verdict, riskMask);
    }
}
