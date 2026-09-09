// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

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
contract EnsIdentityRegistry is IIdentityRegistry {
    using AddressHelper for address;

    IEnsRegistry public immutable ens;

    constructor(address ens_) {
        ens_.zeroAddressCheck();
        ens = IEnsRegistry(ens_);
    }

    function resolve(bytes32 srcId) external view returns (address) {
        address resolver = ens.resolver(srcId);
        if (resolver == address(0)) return address(0);
        try IAddrResolver(resolver).addr(srcId) returns (address a) {
            return a;
        } catch {
            return address(0);
        }
    }
}
