# IERC165
[Git Source](https://github.com/passat-b6-tdi/Portcullis/blob/fd346da22903543af8bd77db9de28f1fa6aaf124/contracts/oracle/ReceiverTemplate.sol)

**Title:**
Minimal ERC-165 interface.


## Functions
### supportsInterface

Reports whether this contract implements an interface.


```solidity
function supportsInterface(bytes4 interfaceId) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`interfaceId`|`bytes4`|ERC-165 interface identifier.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True when the interface is supported.|


