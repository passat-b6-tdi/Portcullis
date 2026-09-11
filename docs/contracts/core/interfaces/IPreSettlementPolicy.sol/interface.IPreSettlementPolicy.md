# IPreSettlementPolicy
[Git Source](https://github.com/passat-b6-tdi/Portcullis/blob/fd346da22903543af8bd77db9de28f1fa6aaf124/contracts/core/interfaces/IPreSettlementPolicy.sol)

**Title:**
Interface for a confidential or external policy verdict keyed by a settlement digest.


## Functions
### evaluate

Returns the current policy verdict and risk flags for a settlement digest.


```solidity
function evaluate(bytes32 msgHash, bytes calldata attestation) external view returns (uint8 verdict, uint8 riskMask);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`msgHash`|`bytes32`|Chain- and guard-bound digest of the settlement message.|
|`attestation`|`bytes`|Policy-specific evidence supplied with the settlement.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`verdict`|`uint8`|Policy code, where Portcullis accepts only explicit ALLOW.|
|`riskMask`|`uint8`|Bitmask describing policy risk reasons.|


