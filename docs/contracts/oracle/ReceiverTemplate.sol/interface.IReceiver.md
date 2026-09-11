# IReceiver
[Git Source](https://github.com/passat-b6-tdi/Portcullis/blob/fd346da22903543af8bd77db9de28f1fa6aaf124/contracts/oracle/ReceiverTemplate.sol)

**Inherits:**
[IERC165](/docs/contracts/oracle/ReceiverTemplate.sol/interface.IERC165.md)

**Title:**
Interface for receiving authenticated Chainlink CRE reports.


## Functions
### onReport

Processes a report delivered by the configured CRE forwarder.


```solidity
function onReport(bytes calldata metadata, bytes calldata report) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`metadata`|`bytes`|CRE-supplied report metadata, ignored by ReceiverTemplate.|
|`report`|`bytes`|ABI-encoded report payload interpreted by the implementation.|


