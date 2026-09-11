# TripReason
[Git Source](https://github.com/passat-b6-tdi/Portcullis/blob/fd346da22903543af8bd77db9de28f1fa6aaf124/contracts/core/types/GuardTypes.sol)

**Title:**
Reason a settlement was rejected by the guard.


```solidity
enum TripReason {
NONE,
BINDING,
BOUNDS,
REPLAY,
NONCE_GAP,
RATE_LIMIT,
VOLUME_SPIKE,
POLICY,
EXPIRED,
POLICY_HOLD
}
```

