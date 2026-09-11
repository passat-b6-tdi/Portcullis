# AddressBookRegistry
[Git Source](https://github.com/passat-b6-tdi/Portcullis/blob/fd346da22903543af8bd77db9de28f1fa6aaf124/contracts/identity/AddressBookRegistry.sol)

**Inherits:**
[IIdentityRegistry](/docs/contracts/core/interfaces/IIdentityRegistry.sol/interface.IIdentityRegistry.md), Ownable

**Title:**
Owner-managed source-to-authority registry.


## State Variables
### _authority
Authority address assigned to each source identifier.


```solidity
mapping(bytes32 => address) internal _authority
```


## Functions
### constructor

Initializes the registry owner.


```solidity
constructor(address owner_) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner_`|`address`|Account permitted to manage authorities.|


### setAuthority

Sets the authority for one source.


```solidity
function setAuthority(bytes32 srcId, address authority) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`srcId`|`bytes32`|Source identifier to update.|
|`authority`|`address`|Nonzero signing authority for the source.|


### setAuthorities

Sets authorities for several sources atomically.

Reverts with LengthMismatch when the arrays differ, or ZeroAddress when any authority is zero.


```solidity
function setAuthorities(bytes32[] calldata srcIds, address[] calldata authorities) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`srcIds`|`bytes32[]`|Source identifiers to update.|
|`authorities`|`address[]`|Matching nonzero signing authorities.|


### renounceOwnership

Disables ownership renunciation so registry administration cannot be permanently abandoned.

Always reverts with Ownable.Unauthorized.


```solidity
function renounceOwnership() public payable override onlyOwner;
```

### resolve

Resolves a source identifier to the address authorized to sign its messages.

Implementations return address(0) for unknown or unresolvable sources; the guard fails closed.


```solidity
function resolve(bytes32 srcId) external view returns (address);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`srcId`|`bytes32`|Source identifier in a SettlementMessage.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|authority Signing authority, or address(0) when the source cannot be resolved.|


## Events
### AuthoritySet
Emitted when a source's signing authority is set or replaced.


```solidity
event AuthoritySet(bytes32 indexed srcId, address authority);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`srcId`|`bytes32`|Source identifier.|
|`authority`|`address`|Nonzero address authorized to sign for the source.|

## Errors
### LengthMismatch
Raised when parallel source and authority arrays have different lengths.


```solidity
error LengthMismatch();
```

