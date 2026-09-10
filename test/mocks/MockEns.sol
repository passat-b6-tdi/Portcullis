// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

contract MockUniversalResolver {
    error ResolverNotFound(bytes name);
    error OffchainLookup(address sender, string[] urls, bytes callData, bytes4 callbackFunction, bytes extraData);

    enum Mode {
        Ok,
        ResolverMissing,
        ResolverDown,
        Offchain,
        EmptyResult
    }

    Mode public mode;
    mapping(bytes32 => address) internal _addr;
    mapping(bytes32 => bool) internal _hasResolver;

    function setAddr(bytes32 node, address a) external {
        _addr[node] = a;
        _hasResolver[node] = true;
    }

    function setHasResolver(bytes32 node, bool v) external {
        _hasResolver[node] = v;
    }

    function setMode(Mode m) external {
        mode = m;
    }

    function resolve(bytes calldata name, bytes calldata data) external view returns (bytes memory, address) {
        if (mode == Mode.ResolverDown) revert("resolver down");
        if (mode == Mode.Offchain) {
            revert OffchainLookup(address(this), new string[](0), data, bytes4(0), "");
        }
        if (mode == Mode.EmptyResult) return (hex"", address(this));

        bytes32 node = abi.decode(data[4:], (bytes32));
        if (mode == Mode.ResolverMissing || !_hasResolver[node]) revert ResolverNotFound(name);
        return (abi.encode(_addr[node]), address(this));
    }
}
