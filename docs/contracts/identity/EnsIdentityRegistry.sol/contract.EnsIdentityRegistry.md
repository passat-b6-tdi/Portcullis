# EnsIdentityRegistry
[Git Source](https://github.com/passat-b6-tdi/Portcullis/blob/fd346da22903543af8bd77db9de28f1fa6aaf124/contracts/identity/EnsIdentityRegistry.sol)

**Inherits:**
[IIdentityRegistry](/docs/contracts/core/interfaces/IIdentityRegistry.sol/interface.IIdentityRegistry.md), Ownable

**Title:**
ENS-backed source authority registry with an owner-managed node allowlist.

Resolver failures, CCIP-Read responses, and malformed results resolve to address(0), allowing the guard to fail closed.


## State Variables
### universalResolver
ENS Universal Resolver used to query on-chain address records.


```solidity
IUniversalResolver public immutable universalResolver
```


### dnsName
DNS-encoded name for each allowed node; an empty value means the node is not allowlisted.


```solidity
mapping(bytes32 => bytes) public dnsName
```


## Functions
### constructor

Initializes the resolver endpoint and registry owner.


```solidity
constructor(address universalResolver_, address owner_) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`universalResolver_`|`address`|Nonzero ENS Universal Resolver address.|
|`owner_`|`address`|Account permitted to manage the node allowlist.|


### allow

Allowlists an ENS node and stores its DNS-encoded name.


```solidity
function allow(bytes32 node, bytes calldata name) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`node`|`bytes32`|ENS namehash used as the source identifier.|
|`name`|`bytes`|Nonempty DNS-encoded ENS name.|


### allowBatch

Allowlists several ENS nodes atomically.

Reverts with EmptyName when arrays differ in length or any name is empty.


```solidity
function allowBatch(bytes32[] calldata nodes, bytes[] calldata names) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`nodes`|`bytes32[]`|ENS namehashes to allow.|
|`names`|`bytes[]`|Matching DNS-encoded names.|


### revoke

Removes an ENS node from the allowlist.


```solidity
function revoke(bytes32 node) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`node`|`bytes32`|ENS namehash to revoke.|


### renounceOwnership

Disables ownership renunciation so the ENS allowlist remains manageable.

Always reverts with Ownable.Unauthorized.


```solidity
function renounceOwnership() public payable override onlyOwner;
```

### resolve

Resolves a source identifier to the address authorized to sign its messages.

Returns address(0) when the node is not allowlisted, resolution reverts, or the result is not exactly one encoded address.


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
### NodeAllowed
Emitted when an ENS node is allowlisted or revoked.


```solidity
event NodeAllowed(bytes32 indexed node, bool allowed);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`node`|`bytes32`|ENS namehash.|
|`allowed`|`bool`|Whether the node is now allowlisted.|

## Errors
### EmptyName
Raised when an allowlisted DNS name is empty.


```solidity
error EmptyName();
```

