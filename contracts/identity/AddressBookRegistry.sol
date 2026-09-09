// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Ownable } from "solady/auth/Ownable.sol";
import { IIdentityRegistry } from "../core/interfaces/IIdentityRegistry.sol";
import { AddressHelper } from "../AddressHelper.sol";

contract AddressBookRegistry is IIdentityRegistry, Ownable {
    using AddressHelper for address;

    error LengthMismatch();

    event AuthoritySet(bytes32 indexed srcId, address authority);

    mapping(bytes32 => address) internal _authority;

    constructor(address owner_) {
        owner_.zeroAddressCheck();
        _initializeOwner(owner_);
    }

    function setAuthority(bytes32 srcId, address authority) external onlyOwner {
        authority.zeroAddressCheck();
        _authority[srcId] = authority;
        emit AuthoritySet(srcId, authority);
    }

    function setAuthorities(bytes32[] calldata srcIds, address[] calldata authorities) external onlyOwner {
        require(srcIds.length == authorities.length, LengthMismatch());
        for (uint256 i = 0; i < srcIds.length; i++) {
            authorities[i].zeroAddressCheck();
            _authority[srcIds[i]] = authorities[i];
            emit AuthoritySet(srcIds[i], authorities[i]);
        }
    }

    function renounceOwnership() public payable override onlyOwner {
        revert Unauthorized();
    }

    function resolve(bytes32 srcId) external view returns (address) {
        return _authority[srcId];
    }
}
