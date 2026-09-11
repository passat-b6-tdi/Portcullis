# VolumeStat
[Git Source](https://github.com/passat-b6-tdi/Portcullis/blob/fd346da22903543af8bd77db9de28f1fa6aaf124/contracts/core/types/GuardTypes.sol)

**Title:**
Per-source history used by the local volume-spike detector.


```solidity
struct VolumeStat {
/// @notice Running mean during warmup, then EMA, of accepted 18-decimal-normalized values.
uint256 baseline;
/// @notice Number of accepted messages included in the baseline.
uint256 observations;
}
```

