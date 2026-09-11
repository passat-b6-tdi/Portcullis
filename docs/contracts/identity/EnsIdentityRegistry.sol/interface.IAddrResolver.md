# IAddrResolver
[Git Source](https://github.com/passat-b6-tdi/Portcullis/blob/fd346da22903543af8bd77db9de28f1fa6aaf124/contracts/identity/EnsIdentityRegistry.sol)

**Title:**
Minimal ENS address-record resolver interface.


## Functions
### addr

Returns the address record for an ENS node.


```solidity
function addr(bytes32 node) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`node`|`bytes32`|ENS namehash.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|Address stored in the resolver record.|


