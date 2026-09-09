// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Ownable } from "solady/auth/Ownable.sol";
import { IIdentityRegistry } from "../core/interfaces/IIdentityRegistry.sol";
import { AddressHelper } from "../AddressHelper.sol";

interface IEnsRegistry {
    function resolver(bytes32 node) external view returns (address);
}

interface IAddrResolver {
    function addr(bytes32 node) external view returns (address);
}

// srcId is the ENS namehash of an org subname (e.g. namehash("treasury.acme.portcullis.eth")).
// Resolution follows the classic registry -> resolver -> addr(node) path, which ENSv2
// preserves for any node that has a resolver (own or inherited from an ancestor).
// Only nodes the owner has explicitly allowlisted resolve to a non-zero authority -
// an arbitrary ENS name (or an ancestor-controlled child) is not a settlement source.
contract EnsIdentityRegistry is IIdentityRegistry, Ownable {
    using AddressHelper for address;

    event NodeAllowed(bytes32 indexed node, bool allowed);

    IEnsRegistry public immutable ens;

    mapping(bytes32 => bool) public allowed;

    constructor(address ens_, address owner_) {
        ens_.zeroAddressCheck();
        owner_.zeroAddressCheck();
        ens = IEnsRegistry(ens_);
        _initializeOwner(owner_);
    }

    function setAllowed(bytes32 node, bool value) external onlyOwner {
        allowed[node] = value;
        emit NodeAllowed(node, value);
    }

    function setAllowedBatch(bytes32[] calldata nodes, bool value) external onlyOwner {
        for (uint256 i = 0; i < nodes.length; i++) {
            allowed[nodes[i]] = value;
            emit NodeAllowed(nodes[i], value);
        }
    }

    function renounceOwnership() public payable override onlyOwner {
        revert Unauthorized();
    }

    function resolve(bytes32 srcId) external view returns (address) {
        if (!allowed[srcId]) return address(0);
        address resolver = ens.resolver(srcId);
        if (resolver == address(0)) return address(0);
        try IAddrResolver(resolver).addr(srcId) returns (address a) {
            return a;
        } catch {
            return address(0);
        }
    }
}
