# SettlementMessage
[Git Source](https://github.com/passat-b6-tdi/Portcullis/blob/fd346da22903543af8bd77db9de28f1fa6aaf124/contracts/core/types/GuardTypes.sol)

**Title:**
Settlement message evaluated before an adapter releases value.


```solidity
struct SettlementMessage {
/// @notice Guardian-enrolled source identifier, such as an organization subname's namehash.
bytes32 srcId;
/// @notice Beneficiary that receives the settlement on this chain.
address recipient;
/// @notice Settlement asset on this chain.
address token;
/// @notice Settlement amount expressed in the token's native decimals.
uint256 value;
/// @notice Per-source sequence number, which must be exactly one greater than the last accepted nonce.
uint256 appNonce;
/// @notice Unix timestamp after which the message is rejected.
uint256 deadline;
}
```

