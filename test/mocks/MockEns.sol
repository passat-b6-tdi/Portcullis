// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

contract MockEnsResolver {
    mapping(bytes32 => address) internal _addr;
    bool public doRevert;

    function setAddr(bytes32 node, address a) external {
        _addr[node] = a;
    }

    function setRevert(bool v) external {
        doRevert = v;
    }

    function addr(bytes32 node) external view returns (address) {
        require(!doRevert, "resolver down");
        return _addr[node];
    }
}

contract MockEnsRegistry {
    mapping(bytes32 => address) public resolver;

    function setResolver(bytes32 node, address r) external {
        resolver[node] = r;
    }
}
