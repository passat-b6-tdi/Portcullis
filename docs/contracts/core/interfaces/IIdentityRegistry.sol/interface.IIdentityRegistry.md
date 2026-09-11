# IIdentityRegistry
[Git Source](https://github.com/passat-b6-tdi/Portcullis/blob/fd346da22903543af8bd77db9de28f1fa6aaf124/contracts/core/interfaces/IIdentityRegistry.sol)

**Title:**
Source authority resolver used by PortcullisGuard.


## Functions
### resolve

Resolves a source identifier to the address authorized to sign its messages.

Implementations return address(0) for unknown or unresolvable sources; the guard fails closed.


```solidity
function resolve(bytes32 srcId) external view returns (address authority);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`srcId`|`bytes32`|Source identifier in a SettlementMessage.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`authority`|`address`|Signing authority, or address(0) when the source cannot be resolved.|


