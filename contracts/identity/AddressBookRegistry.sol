// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Ownable } from "solady/auth/Ownable.sol";
import { IIdentityRegistry } from "../core/interfaces/IIdentityRegistry.sol";
import { AddressHelper } from "../AddressHelper.sol";

/// @title Owner-managed source-to-authority registry.
contract AddressBookRegistry is IIdentityRegistry, Ownable {
    using AddressHelper for address;

    /// @notice Raised when parallel source and authority arrays have different lengths.
    error LengthMismatch();

    /// @notice Emitted when a source's signing authority is set or replaced.
    /// @param srcId Source identifier.
    /// @param authority Nonzero address authorized to sign for the source.
    event AuthoritySet(bytes32 indexed srcId, address authority);

    /// @notice Authority address assigned to each source identifier.
    mapping(bytes32 => address) internal _authority;

    /// @notice Initializes the registry owner.
    /// @param owner_ Account permitted to manage authorities.
    constructor(address owner_) {
        owner_.zeroAddressCheck();
        _initializeOwner(owner_);
    }

    /// @notice Sets the authority for one source.
    /// @param srcId Source identifier to update.
    /// @param authority Nonzero signing authority for the source.
    function setAuthority(bytes32 srcId, address authority) external onlyOwner {
        authority.zeroAddressCheck();
        _authority[srcId] = authority;
        emit AuthoritySet(srcId, authority);
    }

    /// @notice Sets authorities for several sources atomically.
    /// @dev Reverts with LengthMismatch when the arrays differ, or ZeroAddress when any authority is zero.
    /// @param srcIds Source identifiers to update.
    /// @param authorities Matching nonzero signing authorities.
    function setAuthorities(bytes32[] calldata srcIds, address[] calldata authorities) external onlyOwner {
        require(srcIds.length == authorities.length, LengthMismatch());
        for (uint256 i = 0; i < srcIds.length; i++) {
            authorities[i].zeroAddressCheck();
            _authority[srcIds[i]] = authorities[i];
            emit AuthoritySet(srcIds[i], authorities[i]);
        }
    }

    /// @notice Disables ownership renunciation so registry administration cannot be permanently abandoned.
    /// @dev Always reverts with Ownable.Unauthorized.
    function renounceOwnership() public payable override onlyOwner {
        revert Unauthorized();
    }

    /// @inheritdoc IIdentityRegistry
    function resolve(bytes32 srcId) external view returns (address) {
        return _authority[srcId];
    }
}
