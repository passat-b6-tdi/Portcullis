# PortcullisChecks
[Git Source](https://github.com/passat-b6-tdi/Portcullis/blob/fd346da22903543af8bd77db9de28f1fa6aaf124/contracts/core/PortcullisChecks.sol)

**Title:**
Delegated settlement validation and commit logic for PortcullisGuard.

Calls execute in the guard's storage context through DELEGATECALL. evaluate is view-only; commit is called only after it clears.


## State Variables
### BIT_BINDING
Bit set in PASS_MASK for a successful source-binding check.


```solidity
uint8 internal constant BIT_BINDING = 1 << 0
```


### BIT_BOUNDS
Bit set in PASS_MASK for a successful normalized-bounds check.


```solidity
uint8 internal constant BIT_BOUNDS = 1 << 1
```


### BIT_REPLAY
Bit set in PASS_MASK for successful replay and nonce-ordering checks.


```solidity
uint8 internal constant BIT_REPLAY = 1 << 2
```


### BIT_RATE
Bit set in PASS_MASK for a successful rate-limit check.


```solidity
uint8 internal constant BIT_RATE = 1 << 3
```


### BIT_VOLUME
Bit set in PASS_MASK for a successful volume check.


```solidity
uint8 internal constant BIT_VOLUME = 1 << 4
```


### BIT_POLICY
Bit set in PASS_MASK for a successful pre-settlement policy check.


```solidity
uint8 internal constant BIT_POLICY = 1 << 5
```


### PASS_MASK
Mask emitted for a settlement that passed every detector represented by a bit.


```solidity
uint8 internal constant PASS_MASK = BIT_BINDING | BIT_BOUNDS | BIT_REPLAY | BIT_RATE | BIT_VOLUME | BIT_POLICY
```


### POLICY_ALLOW
CRE code that explicitly permits a settlement.


```solidity
uint8 internal constant POLICY_ALLOW = 1
```


### POLICY_DENY
CRE code that rejects a settlement and causes the guard to latch.


```solidity
uint8 internal constant POLICY_DENY = 2
```


### BPS
Basis-point denominator used for local volume thresholds.


```solidity
uint256 private constant BPS = 10_000
```


### EMA_ALPHA
Smoothing denominator for the local exponential moving average.


```solidity
uint256 private constant EMA_ALPHA = 8
```


## Functions
### digest

Computes the chain- and guard-specific settlement digest.


```solidity
function digest(SettlementMessage calldata m) internal view returns (bytes32);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`m`|`SettlementMessage`|Settlement message to hash.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|Message digest used for signatures, replay protection, and policy verdicts.|


### _normalise

Converts a token-native message value to 18-decimal-normalized units.

A zero scale means the token is not allowlisted; multiplication overflow also fails normalization.


```solidity
function _normalise(GuardState storage s, SettlementMessage calldata m)
    private
    view
    returns (uint256 norm, bool ok);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`s`|`GuardState`|Guard storage containing token scales.|
|`m`|`SettlementMessage`|Settlement whose value is normalized.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`norm`|`uint256`|Normalized value when conversion succeeds.|
|`ok`|`bool`|Whether the token was allowed and conversion did not overflow.|


### evaluate

Runs all settlement detectors in order without mutating guard storage.

Identity, policy, and external volume checks run during this view-only delegated call. A policy DENY is distinct because the guard latches it.


```solidity
function evaluate(
    GuardState storage s,
    SettlementMessage calldata m,
    IIdentityRegistry identity,
    bytes calldata proof
) external view returns (bool ok, TripReason reason);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`s`|`GuardState`|Guard storage.|
|`m`|`SettlementMessage`|Proposed settlement message.|
|`identity`|`IIdentityRegistry`|Registry used to resolve the source signing authority.|
|`proof`|`bytes`|Authority signature and any policy or oracle evidence.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ok`|`bool`|Whether every detector cleared.|
|`reason`|`TripReason`|First rejection reason when ok is false.|


### commit

Commits replay, nonce, rate, and local-volume state for an approved settlement.

Must be called only after evaluate returns true. It does not call the external identity, policy, or volume contracts.


```solidity
function commit(GuardState storage s, SettlementMessage calldata m) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`s`|`GuardState`|Guard storage to update.|
|`m`|`SettlementMessage`|Settlement whose acceptance is committed.|


### _available

Calculates the token-bucket allowance available at the current timestamp.


```solidity
function _available(GuardState storage s) private view returns (uint256);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`s`|`GuardState`|Guard storage containing bucket state.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|Available normalized allowance capped at rateCapacity.|


### _volumeOk

Checks a settlement against the configured external or local volume policy.

An external oracle replaces local EMA checks. With neither oracle nor spike factor, volume checking is disabled.


```solidity
function _volumeOk(
    GuardState storage s,
    SettlementMessage calldata m,
    uint256 norm,
    bytes32 mid,
    bytes calldata proof
) private view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`s`|`GuardState`|Guard storage containing volume configuration and history.|
|`m`|`SettlementMessage`|Settlement whose source selects local history.|
|`norm`|`uint256`|Settlement value in 18-decimal-normalized units.|
|`mid`|`bytes32`|Chain- and guard-bound settlement digest.|
|`proof`|`bytes`|Evidence passed to an external oracle, when configured.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|True when the configured volume policy permits the settlement.|


