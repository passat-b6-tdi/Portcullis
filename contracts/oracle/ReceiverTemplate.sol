// SPDX-License-Identifier: MIT
pragma solidity 0.8.36;

/// @title Minimal ERC-165 interface.
interface IERC165 {
    /// @notice Reports whether this contract implements an interface.
    /// @param interfaceId ERC-165 interface identifier.
    /// @return True when the interface is supported.
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

/// @title Interface for receiving authenticated Chainlink CRE reports.
interface IReceiver is IERC165 {
    /// @notice Processes a report delivered by the configured CRE forwarder.
    /// @param metadata CRE-supplied report metadata, ignored by ReceiverTemplate.
    /// @param report ABI-encoded report payload interpreted by the implementation.
    function onReport(bytes calldata metadata, bytes calldata report) external;
}

/// @title Base receiver for reports delivered by a trusted CRE forwarder.
/// @dev Implementations must validate and process their report format in _processReport.
abstract contract ReceiverTemplate is IReceiver {
    /// @notice Address exclusively authorized to submit reports.
    address internal _forwarder;

    /// @notice Raised when the constructor receives a zero forwarder address.
    error InvalidForwarder();
    /// @notice Raised when a caller other than the configured forwarder submits a report.
    error InvalidSender();

    /// @notice Sets the sole report forwarder.
    /// @param forwarder_ Nonzero address permitted to call onReport.
    constructor(address forwarder_) {
        if (forwarder_ == address(0)) revert InvalidForwarder();
        _forwarder = forwarder_;
    }

    /// @notice Returns the address currently authorized to forward reports.
    /// @return Forwarder address.
    function getForwarderAddress() external view returns (address) {
        return _forwarder;
    }

    /// @notice Validates the report sender and dispatches the report payload to the implementation.
    /// @inheritdoc IReceiver
    /// @dev Reverts with InvalidSender unless msg.sender is _forwarder; metadata is intentionally ignored.
    /// @param report Report payload for _processReport.
    function onReport(bytes calldata, bytes calldata report) external virtual override {
        if (msg.sender != _forwarder) revert InvalidSender();
        _processReport(report);
    }

    /// @notice Reports support for IReceiver and IERC165.
    /// @param interfaceId ERC-165 interface identifier to query.
    /// @return True for IReceiver or IERC165, otherwise false.
    function supportsInterface(bytes4 interfaceId) public pure virtual override returns (bool) {
        return interfaceId == type(IReceiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    /// @notice Changes the authorized report forwarder.
    /// @param forwarder_ New forwarder address.
    function setForwarderAddress(address forwarder_) external virtual;

    /// @notice Processes a report that has already been authenticated by onReport.
    /// @param report Implementation-specific report payload.
    function _processReport(bytes calldata report) internal virtual;
}
