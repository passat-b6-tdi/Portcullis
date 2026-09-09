// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

library AddressHelper {
    error ZeroAddress();

    function zeroAddressCheck(address account) external pure {
        require(account != address(0), ZeroAddress());
    }
}
