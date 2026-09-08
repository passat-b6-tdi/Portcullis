// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IVolumeVerdictOracle } from "../../contracts/core/interfaces/IVolumeVerdictOracle.sol";

contract MockVolumeOracle is IVolumeVerdictOracle {
    bool public verdict = true;

    function setVerdict(bool value) external {
        verdict = value;
    }

    function verify(bytes32, bytes calldata) external view returns (bool) {
        return verdict;
    }
}
