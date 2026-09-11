# GuardState
[Git Source](https://github.com/passat-b6-tdi/Portcullis/blob/fd346da22903543af8bd77db9de28f1fa6aaf124/contracts/core/types/GuardTypes.sol)

**Title:**
Storage backing PortcullisGuard and its delegated checking library.

The guard invokes PortcullisChecks by DELEGATECALL, so the library reads and commits this storage in the guard's context.


```solidity
struct GuardState {
/// @notice Whether the circuit breaker currently rejects all adapter submissions.
bool paused;
/// @notice Whether each source identifier has been approved by a guardian.
mapping(bytes32 => bool) enrolled;
/// @notice Inclusive lower value bound in 18-decimal-normalized units.
uint256 minValue;
/// @notice Inclusive upper value bound in 18-decimal-normalized units.
uint256 maxValue;
/// @notice Per-token normalization multiplier; zero means that token is not allowed.
mapping(address => uint256) tokenScale;
/// @notice Whether a message digest has already been accepted.
mapping(bytes32 => bool) seen;
/// @notice Last accepted application nonce for each source.
mapping(bytes32 => uint256) lastNonce;
/// @notice Token-bucket capacity in 18-decimal-normalized units; zero disables rate limiting.
uint256 rateCapacity;
/// @notice Token-bucket refill rate per second in 18-decimal-normalized units.
uint256 rateRefillPerSec;
/// @notice Unrefilled token-bucket allowance remaining at lastRefill.
uint256 tokens;
/// @notice Timestamp from which token-bucket refill is calculated.
uint256 lastRefill;
/// @notice Optional external volume oracle; when present it replaces local EMA volume checks.
IVolumeVerdictOracle volumeOracle;
/// @notice Largest permitted local volume as basis points of the source baseline, where 30,000 means 3.0x.
uint256 spikeFactorBps;
/// @notice Number of accepted source messages required before local spike checks start.
uint256 warmup;
/// @notice Local rolling volume history for each source.
mapping(bytes32 => VolumeStat) volume;
/// @notice Optional confidential pre-settlement policy; a zero address skips this detector.
IPreSettlementPolicy policy;
}
```

