# Portcullis

[Source on GitHub](https://github.com/passat-b6-tdi/Portcullis)

Portcullis is a guard for inbound cross-chain settlements. A settlement adapter
asks `PortcullisGuard` to inspect every message before it transfers a token to a
recipient. The guard is intended for operators who need independent controls at
the receiving contract, even when a transport has already delivered a message.

> Testnet software. The contracts have not been independently audited and are
> not represented as production-ready.

## What it protects

Before value moves, the guard checks that a message is current, comes from an
enrolled source and its resolved signing authority, names an allowed token and
recipient, fits configured value bounds, has the next nonce, and has not been
accepted before. It can also enforce a token-bucket rate limit, a local
per-source volume threshold, and a pre-settlement policy verdict.

Malformed, expired, or unauthenticated messages are rejected without pausing
the lane. An authenticated rate-limit breach, volume spike, or explicit policy
denial latches the circuit breaker until a guardian clears it.

## Main flow

1. An adapter decodes a `SettlementMessage` and its authority signature.
2. The adapter calls `PortcullisGuard.inspect`.
3. If every detector passes, the guard commits replay, nonce, rate, and local
   volume state.
4. The adapter transfers the approved token and emits `SettlementPaid`.
5. If a detector rejects the message, the adapter emits `SettlementRejected`.
   Only configured anomaly reasons also latch the breaker.

`digest(m) = keccak256(abi.encode(block.chainid, address(guard), m))` is the
message identifier. It binds signatures, replay protection, and policy verdicts
to one guard on one chain.

## Architecture

```text
settlement wire
  -> GuardedReceiver adapter
  -> PortcullisGuard.inspect(message, proof)
  -> PortcullisChecks.evaluate
  -> accepted: commit state -> adapter transfer
     rejected: SettlementRejected
```

`AddressBookRegistry` resolves guardian-managed source authorities.
`EnsIdentityRegistry` resolves a guardian-allowlisted ENS name and fails closed
when the name has no usable on-chain address record. `CrePolicyConsumer` stores
time-limited Chainlink CRE policy verdicts. The dashboard and subgraph expose
the state and events of the Sepolia deployment.

## Contracts and guarantees

The contract reference is in [`docs/contracts/`](docs/contracts/README.md).
The security model, trust boundaries, and invariants are in
[`docs/security-notes.md`](docs/security-notes.md).

The important guarantees are:

- Only a guardian-enrolled adapter can call `inspect`.
- A cleared message was signed by the authority resolved for its enrolled
  source, and is bound to the current chain and guard address.
- A cleared digest cannot clear again, and each source nonce advances by one.
- Guard state is committed only after all checks pass.
- Guard-state writes make no attacker-controlled external call. Identity,
  policy, and external-volume checks run in the view evaluation step.

## Run the local demo

Requirements: Foundry with Solidity 0.8.36 and the dependencies in `lib/`.

```bash
forge build
forge test
forge script script/Demo.s.sol
```

`Demo.s.sol` deploys a local guard, receiver, registry, and test token. It
demonstrates an approved settlement, a rejected forged message, a breaker latch
on an authenticated anomaly, and guardian recovery.

To run the dashboard against the public Sepolia deployment:

```bash
cd offchain/dashboard
npm install
npm run dev
```

The dashboard defaults to the documented Sepolia deployment. Its configuration
can be overridden with public `NEXT_PUBLIC_*` variables described in
[`offchain/dashboard/README.md`](offchain/dashboard/README.md).

## Live deployments and transactions

Addresses, deployment transactions, smoke transactions, and the public
subgraph query endpoint are listed in [`docs/deployments.md`](docs/deployments.md).

## Testing

The suite covers unit behavior, fuzzing, stateful invariants, and historical
attack-pattern replays.

```bash
forge test
forge fmt --check
```

## License and third-party components

Portcullis is released under the [MIT License](LICENSE). It uses Foundry,
Solady, OpenZeppelin Contracts, Chainlink CRE, ENS, The Graph, viem, and Privy.
Each dependency retains its own license and terms.
