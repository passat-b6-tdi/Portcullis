// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { IIdentityRegistry } from "../../contracts/core/interfaces/IIdentityRegistry.sol";

contract MockIdentityRegistry is IIdentityRegistry {
    mapping(bytes32 => address) public authority;

    function setAuthority(bytes32 srcId, address value) external {
        authority[srcId] = value;
    }

    function resolve(bytes32 srcId) external view returns (address) {
        return authority[srcId];
    }
}
