// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

/// @title Small address-validation helpers shared by Portcullis contracts.
library AddressHelper {
    /// @notice Raised when a required address is the zero address.
    error ZeroAddress();

    /// @notice Reverts unless an address is nonzero.
    /// @param account Address to validate.
    function zeroAddressCheck(address account) external pure {
        require(account != address(0), ZeroAddress());
    }
}
