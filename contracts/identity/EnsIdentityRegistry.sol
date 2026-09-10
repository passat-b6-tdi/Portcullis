// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

import { Ownable } from "solady/auth/Ownable.sol";
import { IIdentityRegistry } from "../core/interfaces/IIdentityRegistry.sol";
import { AddressHelper } from "../AddressHelper.sol";

interface IUniversalResolver {
    function resolve(bytes calldata name, bytes calldata data)
        external
        view
        returns (bytes memory result, address resolver);
}

interface IAddrResolver {
    function addr(bytes32 node) external view returns (address);
}

contract EnsIdentityRegistry is IIdentityRegistry, Ownable {
    using AddressHelper for address;

    error EmptyName();

    event NodeAllowed(bytes32 indexed node, bool allowed);

    IUniversalResolver public immutable universalResolver;

    // node => DNS-encoded name
    //empty => not allowlisted
    mapping(bytes32 => bytes) public dnsName;

    constructor(address universalResolver_, address owner_) {
        universalResolver_.zeroAddressCheck();
        owner_.zeroAddressCheck();
        universalResolver = IUniversalResolver(universalResolver_);
        _initializeOwner(owner_);
    }

    function allow(bytes32 node, bytes calldata name) external onlyOwner {
        require(name.length != 0, EmptyName());
        dnsName[node] = name;
        emit NodeAllowed(node, true);
    }

    function allowBatch(bytes32[] calldata nodes, bytes[] calldata names) external onlyOwner {
        require(nodes.length == names.length, EmptyName());
        for (uint256 i = 0; i < nodes.length; i++) {
            require(names[i].length != 0, EmptyName());
            dnsName[nodes[i]] = names[i];
            emit NodeAllowed(nodes[i], true);
        }
    }

    function revoke(bytes32 node) external onlyOwner {
        delete dnsName[node];
        emit NodeAllowed(node, false);
    }

    function renounceOwnership() public payable override onlyOwner {
        revert Unauthorized();
    }

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
