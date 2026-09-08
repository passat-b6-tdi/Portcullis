// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

interface IIdentityRegistry {
    // returns address(0) for an unknown source
    function resolve(bytes32 srcId) external view returns (address authority);
}
