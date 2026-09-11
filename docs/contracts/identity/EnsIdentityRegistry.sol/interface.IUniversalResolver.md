# IUniversalResolver
[Git Source](https://github.com/passat-b6-tdi/Portcullis/blob/fd346da22903543af8bd77db9de28f1fa6aaf124/contracts/identity/EnsIdentityRegistry.sol)

**Title:**
Minimal ENS Universal Resolver interface used for on-chain address resolution.


## Functions
### resolve

Resolves an encoded ENS name and resolver calldata.


```solidity
function resolve(bytes calldata name, bytes calldata data)
    external
    view
    returns (bytes memory result, address resolver);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`name`|`bytes`|DNS-encoded ENS name.|
|`data`|`bytes`|Calldata for the selected ENS resolver method.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`result`|`bytes`|ABI-encoded resolver result.|
|`resolver`|`address`|Resolver that served the response.|


