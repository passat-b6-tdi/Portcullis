// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Ownable } from "solady/auth/Ownable.sol";
import { IIdentityRegistry } from "../core/interfaces/IIdentityRegistry.sol";
import { AddressHelper } from "../AddressHelper.sol";

/// @title Minimal ENS Universal Resolver interface used for on-chain address resolution.
interface IUniversalResolver {
    /// @notice Resolves an encoded ENS name and resolver calldata.
    /// @param name DNS-encoded ENS name.
    /// @param data Calldata for the selected ENS resolver method.
    /// @return result ABI-encoded resolver result.
    /// @return resolver Resolver that served the response.
    function resolve(bytes calldata name, bytes calldata data)
        external
        view
        returns (bytes memory result, address resolver);
}

/// @title Minimal ENS address-record resolver interface.
interface IAddrResolver {
    /// @notice Returns the address record for an ENS node.
    /// @param node ENS namehash.
    /// @return Address stored in the resolver record.
    function addr(bytes32 node) external view returns (address);
}

/// @title ENS-backed source authority registry with an owner-managed node allowlist.
/// @dev Resolver failures, CCIP-Read responses, and malformed results resolve to address(0), allowing the guard to fail closed.
contract EnsIdentityRegistry is IIdentityRegistry, Ownable {
    using AddressHelper for address;

    /// @notice Raised when an allowlisted DNS name is empty.
    error EmptyName();

    /// @notice Emitted when an ENS node is allowlisted or revoked.
    /// @param node ENS namehash.
    /// @param allowed Whether the node is now allowlisted.
    event NodeAllowed(bytes32 indexed node, bool allowed);

    /// @notice ENS Universal Resolver used to query on-chain address records.
    IUniversalResolver public immutable universalResolver;

    /// @notice DNS-encoded name for each allowed node; an empty value means the node is not allowlisted.
    mapping(bytes32 => bytes) public dnsName;

    /// @notice Initializes the resolver endpoint and registry owner.
    /// @param universalResolver_ Nonzero ENS Universal Resolver address.
    /// @param owner_ Account permitted to manage the node allowlist.
    constructor(address universalResolver_, address owner_) {
        universalResolver_.zeroAddressCheck();
        owner_.zeroAddressCheck();
        universalResolver = IUniversalResolver(universalResolver_);
        _initializeOwner(owner_);
    }

    /// @notice Allowlists an ENS node and stores its DNS-encoded name.
    /// @param node ENS namehash used as the source identifier.
    /// @param name Nonempty DNS-encoded ENS name.
    function allow(bytes32 node, bytes calldata name) external onlyOwner {
        require(name.length != 0, EmptyName());
        dnsName[node] = name;
        emit NodeAllowed(node, true);
    }

    /// @notice Allowlists several ENS nodes atomically.
    /// @dev Reverts with EmptyName when arrays differ in length or any name is empty.
    /// @param nodes ENS namehashes to allow.
    /// @param names Matching DNS-encoded names.
    function allowBatch(bytes32[] calldata nodes, bytes[] calldata names) external onlyOwner {
        require(nodes.length == names.length, EmptyName());
        for (uint256 i = 0; i < nodes.length; i++) {
            require(names[i].length != 0, EmptyName());
            dnsName[nodes[i]] = names[i];
            emit NodeAllowed(nodes[i], true);
        }
    }

    /// @notice Removes an ENS node from the allowlist.
    /// @param node ENS namehash to revoke.
    function revoke(bytes32 node) external onlyOwner {
        delete dnsName[node];
        emit NodeAllowed(node, false);
    }

    /// @notice Disables ownership renunciation so the ENS allowlist remains manageable.
    /// @dev Always reverts with Ownable.Unauthorized.
    function renounceOwnership() public payable override onlyOwner {
        revert Unauthorized();
    }

    /// @inheritdoc IIdentityRegistry
    /// @dev Returns address(0) when the node is not allowlisted, resolution reverts, or the result is not exactly one encoded address.
    function resolve(bytes32 srcId) external view returns (address) {
        bytes memory name = dnsName[srcId];
        if (name.length == 0) return address(0);

        try universalResolver.resolve(name, abi.encodeCall(IAddrResolver.addr, (srcId))) returns (
            bytes memory result, address
        ) {
            if (result.length != 32) return address(0);
            return abi.decode(result, (address));
        } catch {
            return address(0);
        }
    }
}
