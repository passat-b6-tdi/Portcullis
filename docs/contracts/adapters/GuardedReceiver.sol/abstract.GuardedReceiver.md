# GuardedReceiver
[Git Source](https://github.com/passat-b6-tdi/Portcullis/blob/fd346da22903543af8bd77db9de28f1fa6aaf124/contracts/adapters/GuardedReceiver.sol)

**Title:**
Adapter base that passes decoded settlement messages through a PortcullisGuard.

Subclasses define wire decoding and the post-validation settlement action.


## State Variables
### guard
Guard that authorizes messages before this adapter handles them.


```solidity
PortcullisGuard public immutable guard
```


## Functions
### constructor

Sets the guard used by this receiver.

The guard is immutable after construction.


```solidity
constructor(PortcullisGuard guard_) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`guard_`|`PortcullisGuard`|PortcullisGuard that must approve each decoded message.|


### receiveMessage

Decodes, inspects, and, if cleared, processes an inbound settlement wire payload.

A rejection emits SettlementRejected and returns successfully; only approved messages reach _handleValidated.


```solidity
function receiveMessage(bytes calldata wire) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`wire`|`bytes`|Adapter-specific ABI-encoded message and proof.|


### _decode

Decodes an adapter wire payload into a settlement message and proof.


```solidity
function _decode(bytes calldata wire) internal view virtual returns (SettlementMessage memory m, bytes memory proof);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`wire`|`bytes`|Adapter-specific inbound payload.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`m`|`SettlementMessage`|Decoded settlement message.|
|`proof`|`bytes`|Decoded authority signature or policy evidence.|


### _handleValidated

Performs the adapter-specific action for a guard-approved settlement.

Called only after inspect has returned true and committed guard state.


```solidity
function _handleValidated(SettlementMessage memory m) internal virtual;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`m`|`SettlementMessage`|Settlement that has passed inspection and whose guard state has been committed.|


## Events
### SettlementRejected
Emitted when the guard rejects a decoded settlement without reverting the adapter call.


```solidity
event SettlementRejected(bytes32 indexed messageId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`messageId`|`bytes32`|Digest of the rejected settlement message.|

