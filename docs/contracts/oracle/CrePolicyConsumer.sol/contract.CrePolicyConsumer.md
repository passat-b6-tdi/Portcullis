# CrePolicyConsumer
[Git Source](https://github.com/passat-b6-tdi/Portcullis/blob/fd346da22903543af8bd77db9de28f1fa6aaf124/contracts/oracle/CrePolicyConsumer.sol)

**Inherits:**
[ReceiverTemplate](/docs/contracts/oracle/ReceiverTemplate.sol/abstract.ReceiverTemplate.md), Ownable, [IPreSettlementPolicy](/docs/contracts/core/interfaces/IPreSettlementPolicy.sol/interface.IPreSettlementPolicy.md)

**Title:**
Chainlink CRE report consumer that exposes time-limited policy verdicts to PortcullisGuard.

A missing or stale report is not ALLOW, so a connected guard holds the settlement closed.


## State Variables
### UNKNOWN
Verdict returned when no report has been stored for a digest.


```solidity
uint8 internal constant UNKNOWN = 0
```


### STALE
Verdict returned for a report older than maxAge, surfaced as MANUAL_REVIEW.


```solidity
uint8 internal constant STALE = 3
```


### maxAge
Maximum age in seconds for a stored report to remain usable.


```solidity
uint256 public maxAge = 1 hours
```


### _verdict
Stored CRE verdicts keyed by chain- and guard-bound settlement digest.


```solidity
mapping(bytes32 => Verdict) internal _verdict
```


## Functions
### constructor

Initializes the CRE report forwarder and owner.


```solidity
constructor(address forwarder_, address owner_) ReceiverTemplate(forwarder_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`forwarder_`|`address`|Nonzero address authorized to deliver CRE reports.|
|`owner_`|`address`|Account permitted to administer report age and forwarder configuration.|


### evaluate

Returns the current policy verdict and risk flags for a settlement digest.

Ignores attestation because CRE pushes verdicts before inspection. Missing and stale entries intentionally do not return ALLOW.


```solidity
function evaluate(bytes32 msgHash, bytes calldata) external view returns (uint8 verdict, uint8 riskMask);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`msgHash`|`bytes32`|Chain- and guard-bound digest of the settlement message.|
|`<none>`|`bytes`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`verdict`|`uint8`|Policy code, where Portcullis accepts only explicit ALLOW.|
|`riskMask`|`uint8`|Bitmask describing policy risk reasons.|


### verdictOf

Returns the raw stored CRE verdict for a settlement digest.


```solidity
function verdictOf(bytes32 msgHash) external view returns (uint8 code, uint8 riskMask, uint64 issuedAt);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`msgHash`|`bytes32`|Digest whose stored report is queried.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`code`|`uint8`|CRE verdict code.|
|`riskMask`|`uint8`|CRE risk-reason bitmask.|
|`issuedAt`|`uint64`|Unix timestamp embedded in the report.|


### setMaxAge

Sets the period for which a CRE report remains valid.


```solidity
function setMaxAge(uint256 seconds_) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`seconds_`|`uint256`|New maximum report age in seconds; zero makes reports stale immediately after their issuance timestamp.|


### setForwarderAddress

Changes the authorized report forwarder.

Reverts for a zero address and emits ForwarderSet after updating the receiver template's sender gate.


```solidity
function setForwarderAddress(address forwarder_) external override onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`forwarder_`|`address`|New forwarder address.|


### renounceOwnership

Disables ownership renunciation so CRE consumer administration cannot be abandoned.

Always reverts with Ownable.Unauthorized.


```solidity
function renounceOwnership() public payable override onlyOwner;
```

### _processReport

Processes a report that has already been authenticated by onReport.

Decodes report as (bytes32 msgHash, uint8 code, uint8 riskMask, uint64 issuedAt) and overwrites the prior verdict.


```solidity
function _processReport(bytes calldata report) internal override;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`report`|`bytes`|Implementation-specific report payload.|


## Events
### VerdictStored
Emitted after an authenticated CRE report replaces a settlement verdict.


```solidity
event VerdictStored(bytes32 indexed msgHash, uint8 code, uint8 riskMask, uint64 issuedAt);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`msgHash`|`bytes32`|Digest to which the verdict applies.|
|`code`|`uint8`|CRE verdict code: 1 ALLOW, 2 DENY, 3 MANUAL_REVIEW, or 0 none.|
|`riskMask`|`uint8`|Bitmask of policy risk reasons.|
|`issuedAt`|`uint64`|Unix timestamp embedded in the report.|

### MaxAgeSet
Emitted when the maximum accepted report age changes.


```solidity
event MaxAgeSet(uint256 maxAge);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`maxAge`|`uint256`|Maximum report age in seconds.|

### ForwarderSet
Emitted when the authorized CRE report forwarder changes.


```solidity
event ForwarderSet(address forwarder);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`forwarder`|`address`|New forwarder address.|

## Structs
### Verdict
**Title:**
Policy result stored from a CRE report.


```solidity
struct Verdict {
    /// @notice CRE verdict code.
    uint8 code;
    /// @notice CRE risk-reason bitmask.
    uint8 riskMask;
    /// @notice Unix timestamp at which CRE issued the verdict.
    uint64 issuedAt;
}
```

