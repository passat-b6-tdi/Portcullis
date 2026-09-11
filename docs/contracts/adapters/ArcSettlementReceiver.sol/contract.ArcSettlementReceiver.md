# ArcSettlementReceiver
[Git Source](https://github.com/passat-b6-tdi/Portcullis/blob/fd346da22903543af8bd77db9de28f1fa6aaf124/contracts/adapters/ArcSettlementReceiver.sol)

**Inherits:**
[GuardedReceiver](/docs/contracts/adapters/GuardedReceiver.sol/abstract.GuardedReceiver.md)

**Title:**
Guarded receiver that settles approved ERC-20 messages with a direct token transfer.


## Functions
### constructor

Initializes the receiver with its Portcullis guard.

The guard address is immutable through the inherited constructor.


```solidity
constructor(PortcullisGuard guard_) GuardedReceiver(guard_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`guard_`|`PortcullisGuard`|Guard that authorizes inbound settlement messages.|


### _decode

Decodes an adapter wire payload into a settlement message and proof.

Decodes the wire as an ABI tuple of SettlementMessage and proof.


```solidity
function _decode(bytes calldata wire)
    internal
    pure
    override
    returns (SettlementMessage memory m, bytes memory proof);
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

Transfers the approved token only after the guard has committed acceptance state.


```solidity
function _handleValidated(SettlementMessage memory m) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`m`|`SettlementMessage`|Settlement that has passed inspection and whose guard state has been committed.|


## Events
### SettlementPaid
Emitted after an approved settlement token transfer succeeds.


```solidity
event SettlementPaid(bytes32 indexed messageId, address indexed recipient, address token, uint256 value);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`messageId`|`bytes32`|Digest of the paid settlement.|
|`recipient`|`address`|Recipient of the transferred tokens.|
|`token`|`address`|ERC-20 token transferred from this receiver.|
|`value`|`uint256`|Token-native amount transferred.|

