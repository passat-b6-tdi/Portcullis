# ReceiverTemplate
[Git Source](https://github.com/passat-b6-tdi/Portcullis/blob/fd346da22903543af8bd77db9de28f1fa6aaf124/contracts/oracle/ReceiverTemplate.sol)

**Inherits:**
[IReceiver](/docs/contracts/oracle/ReceiverTemplate.sol/interface.IReceiver.md)

**Title:**
Base receiver for reports delivered by a trusted CRE forwarder.

Implementations must validate and process their report format in _processReport.


## State Variables
### _forwarder
Address exclusively authorized to submit reports.


```solidity
address internal _forwarder
```


## Functions
### constructor

Sets the sole report forwarder.


```solidity
constructor(address forwarder_) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`forwarder_`|`address`|Nonzero address permitted to call onReport.|


### getForwarderAddress

Returns the address currently authorized to forward reports.


```solidity
function getForwarderAddress() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Forwarder address.|


### onReport

Validates the report sender and dispatches the report payload to the implementation.

Reverts with InvalidSender unless msg.sender is _forwarder; metadata is intentionally ignored.


```solidity
function onReport(bytes calldata, bytes calldata report) external virtual override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes`||
|`report`|`bytes`|Report payload for _processReport.|


### supportsInterface

Reports support for IReceiver and IERC165.


```solidity
function supportsInterface(bytes4 interfaceId) public pure virtual override returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`interfaceId`|`bytes4`|ERC-165 interface identifier to query.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True for IReceiver or IERC165, otherwise false.|


### setForwarderAddress

Changes the authorized report forwarder.


```solidity
function setForwarderAddress(address forwarder_) external virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`forwarder_`|`address`|New forwarder address.|


### _processReport

Processes a report that has already been authenticated by onReport.


```solidity
function _processReport(bytes calldata report) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`report`|`bytes`|Implementation-specific report payload.|


## Errors
### InvalidForwarder
Raised when the constructor receives a zero forwarder address.


```solidity
error InvalidForwarder();
```

### InvalidSender
Raised when a caller other than the configured forwarder submits a report.


```solidity
error InvalidSender();
```

