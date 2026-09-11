# PortcullisGuard
[Git Source](https://github.com/passat-b6-tdi/Portcullis/blob/fd346da22903543af8bd77db9de28f1fa6aaf124/contracts/core/PortcullisGuard.sol)

**Inherits:**
OwnableRoles

**Title:**
Configurable firewall for inbound cross-chain settlement messages.

Adapters call inspect before releasing funds. Accepted messages commit state only after all delegated checks pass; authenticated rate, volume, and explicit-policy anomalies latch the guard.


## State Variables
### GUARDIAN_ROLE
Role allowed to administer guard configuration and clear the circuit breaker.


```solidity
uint256 public constant GUARDIAN_ROLE = 1 << 0
```


### ADAPTER_ROLE
Role allowed to submit settlements to inspect.


```solidity
uint256 public constant ADAPTER_ROLE = 1 << 1
```


### identity
Registry used to resolve the signing authority for an enrolled source.


```solidity
IIdentityRegistry public immutable identity
```


### _s
Guard state shared with PortcullisChecks during delegated execution.


```solidity
GuardState internal _s
```


## Functions
### constructor

Initializes guard ownership, its first guardian, and the source identity registry.


```solidity
constructor(address _owner, address guardian_, address identity_) ;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_owner`|`address`|Contract owner; ownership cannot later be renounced.|
|`guardian_`|`address`|Initial guardian with configuration and clear authority.|
|`identity_`|`address`|Nonzero source authority registry.|


### inspect

Inspects a settlement submitted by an enrolled adapter and commits it when it clears.

Reverts while paused. Rejections return false rather than reverting; RATE_LIMIT, VOLUME_SPIKE, and explicit POLICY DENY also latch the breaker.


```solidity
function inspect(SettlementMessage calldata m, bytes calldata proof)
    external
    onlyRoles(ADAPTER_ROLE)
    returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`m`|`SettlementMessage`|Proposed settlement message.|
|`proof`|`bytes`|Authority signature plus any policy or oracle evidence.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True when the message passed all checks and its replay, nonce, rate, and local-volume state was committed.|


### digestOf

Computes the digest used by this guard for a settlement.


```solidity
function digestOf(SettlementMessage calldata m) external view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`m`|`SettlementMessage`|Settlement message to hash.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Chain- and guard-bound message digest.|


### clear

Clears the circuit breaker.

Does not undo any configuration or accepted-message state.


```solidity
function clear() external onlyRoles(GUARDIAN_ROLE);
```

### transferGuardian

Transfers the caller's guardian role to a nonzero new guardian.

Reverts for the caller's own address. Other guardians, if any, retain their roles.


```solidity
function transferGuardian(address to) external onlyRoles(GUARDIAN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|Recipient of the caller's guardian role.|


### renounceOwnership

Prevents ownership renunciation.

Always reverts with Portcullis__BadConfig.


```solidity
function renounceOwnership() public payable override onlyOwner;
```

### setEnrolled

Enrolls or removes a source identifier.


```solidity
function setEnrolled(bytes32 srcId, bool value) external onlyRoles(GUARDIAN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`srcId`|`bytes32`|Source identifier to update.|
|`value`|`bool`|Whether the source may pass the binding detector.|


### setAdapter

Grants or removes permission for an adapter to call inspect.


```solidity
function setAdapter(address adapter, bool allowed) external onlyRoles(GUARDIAN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`adapter`|`address`|Nonzero adapter address.|
|`allowed`|`bool`|Whether to grant the adapter role.|


### resetSeen

Clears the replay marker for a message digest.

This does not change the source nonce; a resync may also be required before replaying a message.


```solidity
function resetSeen(bytes32 messageId) external onlyRoles(GUARDIAN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`messageId`|`bytes32`|Digest whose consumed state is removed.|


### resyncNonce

Sets the last accepted nonce for a source.


```solidity
function resyncNonce(bytes32 srcId, uint256 nonce) external onlyRoles(GUARDIAN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`srcId`|`bytes32`|Source identifier to resynchronize.|
|`nonce`|`uint256`|New last accepted nonce, so the next accepted message must use nonce + 1.|


### setBounds

Sets inclusive settlement bounds in 18-decimal-normalized units.

Reverts unless minValue is strictly less than maxValue.


```solidity
function setBounds(uint256 minValue, uint256 maxValue) external onlyRoles(GUARDIAN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minValue`|`uint256`|New lower bound.|
|`maxValue`|`uint256`|New upper bound.|


### setAllowedToken

Allows or disallows a token and records its decimal normalization scale.

Reverts when decimals exceeds 18. Disallowing a token stores a zero scale.


```solidity
function setAllowedToken(address token, bool allowed, uint8 decimals) external onlyRoles(GUARDIAN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token whose entry is changed; zero is technically storable but cannot pass bounds as a usable ERC-20 settlement asset.|
|`allowed`|`bool`|Whether the token is allowed.|
|`decimals`|`uint8`|Token decimal count used to normalize values.|


### setRate

Configures and resets the normalized token-bucket rate limiter.

A capacity of zero disables rate enforcement. Setting either value resets tokens to capacity and lastRefill to now.


```solidity
function setRate(uint256 capacity, uint256 refillPerSec) external onlyRoles(GUARDIAN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`capacity`|`uint256`|Bucket capacity.|
|`refillPerSec`|`uint256`|Tokens refilled per second.|


### setVolumePolicy

Configures external or local volume-spike detection.

A nonzero oracle fully replaces local EMA checks. With no oracle and zero spikeFactorBps, volume checking is disabled.


```solidity
function setVolumePolicy(IVolumeVerdictOracle oracle, uint256 spikeFactorBps, uint256 warmup)
    external
    onlyRoles(GUARDIAN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oracle`|`IVolumeVerdictOracle`|External verdict oracle, or zero for local EMA mode.|
|`spikeFactorBps`|`uint256`|Local threshold in basis points of baseline.|
|`warmup`|`uint256`|Required observations before local enforcement.|


### setPolicy

Sets the optional pre-settlement policy contract.

A zero address disables policy evaluation; a configured policy must return explicit ALLOW for a message to clear.


```solidity
function setPolicy(IPreSettlementPolicy policy_) external onlyRoles(GUARDIAN_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`policy_`|`IPreSettlementPolicy`|Policy contract to query.|


### isGuardian

Checks whether an account has the guardian role.


```solidity
function isGuardian(address account) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Account to query.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True when account is a guardian.|


### isAdapter

Checks whether an account has the adapter role.


```solidity
function isAdapter(address account) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`account`|`address`|Account to query.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True when account may call inspect.|


### enrolled

Returns whether a source identifier is enrolled.


```solidity
function enrolled(bytes32 srcId) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`srcId`|`bytes32`|Source identifier to query.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True when the source is enrolled.|


### paused

Returns whether the circuit breaker is latched.


```solidity
function paused() external view returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True while inspect reverts with Portcullis__Paused.|


### bounds

Returns inclusive normalized settlement bounds.


```solidity
function bounds() external view returns (uint256 minValue, uint256 maxValue);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`minValue`|`uint256`|Lower bound in 18-decimal-normalized units.|
|`maxValue`|`uint256`|Upper bound in 18-decimal-normalized units.|


### allowedToken

Returns whether a token has a nonzero normalization scale.


```solidity
function allowedToken(address token) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token to query.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True when the token is allowed.|


### tokenScale

Returns a token's multiplier for conversion to 18-decimal-normalized units.


```solidity
function tokenScale(address token) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token to query.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Scale, or zero when the token is not allowed.|


### seen

Returns whether a message digest has already been accepted.


```solidity
function seen(bytes32 messageId) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`messageId`|`bytes32`|Digest to query.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True when the digest is marked consumed.|


### lastNonce

Returns a source's last accepted application nonce.


```solidity
function lastNonce(bytes32 srcId) external view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`srcId`|`bytes32`|Source identifier to query.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Last accepted nonce.|


### rateState

Returns the current token-bucket configuration and stored state.


```solidity
function rateState()
    external
    view
    returns (uint256 capacity, uint256 refillPerSec, uint256 tokens, uint256 lastRefill);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`capacity`|`uint256`|Bucket capacity.|
|`refillPerSec`|`uint256`|Bucket refill rate per second.|
|`tokens`|`uint256`|Unrefilled allowance stored at lastRefill.|
|`lastRefill`|`uint256`|Timestamp used as the bucket refill origin.|


### volumeState

Returns the volume detector configuration.


```solidity
function volumeState() external view returns (address oracle, uint256 spikeFactorBps, uint256 warmup);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`oracle`|`address`|External oracle address, or zero for local EMA mode.|
|`spikeFactorBps`|`uint256`|Local spike threshold in basis points.|
|`warmup`|`uint256`|Observations required before local spike enforcement.|


### volumeStatOf

Returns the local volume history for a source.


```solidity
function volumeStatOf(bytes32 srcId) external view returns (uint256 baseline, uint256 observations);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`srcId`|`bytes32`|Source identifier to query.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`baseline`|`uint256`|Current normalized running mean or EMA.|
|`observations`|`uint256`|Number of accepted messages in the history.|


### _latching

Identifies rejection reasons that should latch the circuit breaker.


```solidity
function _latching(TripReason reason) private pure returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`reason`|`TripReason`|Settlement rejection reason.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True for rate-limit, volume-spike, and explicit-policy denial.|


### _trip

Latches the circuit breaker and records its triggering settlement.


```solidity
function _trip(TripReason reason, bytes32 messageId) internal;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`reason`|`TripReason`|Authenticated anomaly that caused the latch.|
|`messageId`|`bytes32`|Digest of the triggering settlement.|


## Events
### SentinelTripped
Emitted when an authenticated anomaly latches the circuit breaker.


```solidity
event SentinelTripped(TripReason reason, bytes32 indexed messageId, address indexed reporter);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`reason`|`TripReason`|Detector that triggered the latch.|
|`messageId`|`bytes32`|Digest of the triggering settlement.|
|`reporter`|`address`|Adapter that submitted the settlement.|

### SentinelCleared
Emitted when a guardian reopens the circuit breaker.


```solidity
event SentinelCleared(address indexed guardian);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`guardian`|`address`|Guardian that cleared the latch.|

### SettlementInspected
Records the result of each inspected settlement.


```solidity
event SettlementInspected(
    bytes32 indexed messageId,
    bytes32 indexed srcId,
    address recipient,
    address token,
    uint256 value,
    bool cleared,
    TripReason reason,
    uint8 detectorMask
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`messageId`|`bytes32`|Chain- and guard-bound settlement digest.|
|`srcId`|`bytes32`|Source identifier from the settlement.|
|`recipient`|`address`|Intended settlement beneficiary.|
|`token`|`address`|Token in which the settlement is denominated.|
|`value`|`uint256`|Token-native settlement amount.|
|`cleared`|`bool`|Whether all checks passed and state was committed.|
|`reason`|`TripReason`|First detector rejection reason, or NONE when cleared.|
|`detectorMask`|`uint8`|PASS_MASK when cleared, otherwise zero.|

### BoundsSet
Emitted when inclusive normalized settlement bounds change.


```solidity
event BoundsSet(uint256 minValue, uint256 maxValue);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minValue`|`uint256`|New lower bound in 18-decimal-normalized units.|
|`maxValue`|`uint256`|New upper bound in 18-decimal-normalized units.|

### TokenAllowed
Emitted when a token allowlist entry is changed.


```solidity
event TokenAllowed(address indexed token, bool allowed, uint8 decimals);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token`|`address`|Token whose entry changed.|
|`allowed`|`bool`|Whether the token is allowed.|
|`decimals`|`uint8`|Token decimals used to derive the normalization scale.|

### RateSet
Emitted when token-bucket rate settings change and the bucket is reset.


```solidity
event RateSet(uint256 capacity, uint256 refillPerSec);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`capacity`|`uint256`|New bucket capacity in 18-decimal-normalized units.|
|`refillPerSec`|`uint256`|New bucket refill rate per second in normalized units.|

### VolumePolicySet
Emitted when the volume detector configuration changes.


```solidity
event VolumePolicySet(address indexed oracle, uint256 spikeFactorBps, uint256 warmup);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oracle`|`address`|External volume oracle, or zero to use local EMA logic.|
|`spikeFactorBps`|`uint256`|Local spike threshold in basis points of baseline.|
|`warmup`|`uint256`|Accepted messages required before local spike enforcement.|

### PolicySet
Emitted when the optional pre-settlement policy contract changes.


```solidity
event PolicySet(address indexed policy);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`policy`|`address`|Policy contract, or zero to disable policy evaluation.|

### GuardianTransferred
Emitted when the current guardian transfers its guardian role.


```solidity
event GuardianTransferred(address indexed from, address indexed to);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|Guardian that relinquished the role.|
|`to`|`address`|New guardian.|

### SourceEnrolled
Emitted when a source enrollment changes.


```solidity
event SourceEnrolled(bytes32 indexed srcId, bool enrolled);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`srcId`|`bytes32`|Source identifier affected.|
|`enrolled`|`bool`|Whether the source is enrolled.|

### AdapterSet
Emitted when an adapter role is granted or removed.


```solidity
event AdapterSet(address indexed adapter, bool allowed);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`adapter`|`address`|Adapter address affected.|
|`allowed`|`bool`|Whether the adapter now has permission to inspect messages.|

### SeenReset
Emitted when replay state is cleared for a message digest.


```solidity
event SeenReset(bytes32 indexed messageId);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`messageId`|`bytes32`|Digest whose seen flag was reset.|

### NonceResynced
Emitted when a source's expected nonce is manually changed.


```solidity
event NonceResynced(bytes32 indexed srcId, uint256 nonce);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`srcId`|`bytes32`|Source identifier affected.|
|`nonce`|`uint256`|New last accepted nonce.|

## Errors
### Portcullis__Paused
Raised when an adapter submits while the circuit breaker is latched.


```solidity
error Portcullis__Paused();
```

### Portcullis__BadConfig
Raised when a guardian supplies an invalid configuration or attempts to renounce ownership.


```solidity
error Portcullis__BadConfig();
```

