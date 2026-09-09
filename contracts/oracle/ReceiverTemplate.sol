// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IReceiver is IERC165 {
    function onReport(bytes calldata metadata, bytes calldata report) external;
}

abstract contract ReceiverTemplate is IReceiver {
    address internal _forwarder;

    error InvalidForwarder();
    error InvalidSender();

    constructor(address forwarder_) {
        if (forwarder_ == address(0)) revert InvalidForwarder();
        _forwarder = forwarder_;
    }

    function getForwarderAddress() external view returns (address) {
        return _forwarder;
    }

    function onReport(bytes calldata, bytes calldata report) external virtual override {
        if (msg.sender != _forwarder) revert InvalidSender();
        _processReport(report);
    }

    function supportsInterface(bytes4 interfaceId) public pure virtual override returns (bool) {
        return interfaceId == type(IReceiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    function setForwarderAddress(address forwarder_) external virtual;

    function _processReport(bytes calldata report) internal virtual;
}
