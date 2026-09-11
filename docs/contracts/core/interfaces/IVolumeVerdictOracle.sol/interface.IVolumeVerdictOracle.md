# IVolumeVerdictOracle
[Git Source](https://github.com/passat-b6-tdi/Portcullis/blob/fd346da22903543af8bd77db9de28f1fa6aaf124/contracts/core/interfaces/IVolumeVerdictOracle.sol)

**Title:**
Interface for an external volume verdict provider.


## Functions
### verify

Verifies whether a settlement passes an external volume policy.


```solidity
function verify(bytes32 msgHash, bytes calldata proof) external view returns (bool ok);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`msgHash`|`bytes32`|Chain- and guard-bound digest of the settlement message.|
|`proof`|`bytes`|Oracle-specific off-chain evidence, such as a TEE signature.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ok`|`bool`|True only when the oracle permits the settlement.|


