# Security model and invariants

Portcullis is a configurable receiving-side control. It does not prove that a
source chain or transport is safe. A guardian chooses the adapter, enrolled
sources, source-authority registry, tokens, limits, and optional policy
providers. Those roles are part of the trust model.

## Trust boundaries

- **Guardian:** manages sources, adapters, value bounds, rate and volume
  policies, optional policy contracts, and breaker recovery.
- **Adapter:** is the only caller allowed to submit a settlement to `inspect`.
  It transfers value only after the guard accepts the message.
- **Identity registry:** supplies the authority that must have signed a message.
  `AddressBookRegistry` is guardian-managed. `EnsIdentityRegistry` resolves
  only names the registry owner allowlists.
- **Optional policy and volume providers:** return a verdict during the
  read-only evaluation step. A configured policy must explicitly return
  `ALLOW`; missing, stale, or manual-review verdicts hold the message.

## Message authentication

For an enrolled `srcId`, the guard resolves an authority and requires a valid
ECDSA signature over the digest:

```text
keccak256(abi.encode(block.chainid, address(guard), SettlementMessage))
```

The digest is both the replay key and the policy-verdict key. Including the
chain ID and guard address prevents a signature or stored verdict for one guard
deployment from being used by another.

## Invariants

- Only an address with `ADAPTER_ROLE` can call `inspect`.
- An accepted message has a nonzero recipient, an allowed token, a normalized
  value within inclusive bounds, an enrolled source, and a valid authority
  signature.
- An accepted digest is marked consumed and cannot be accepted again.
- An accepted source nonce is exactly one greater than its previous accepted
  nonce.
- State that records acceptance is committed only after every detector passes.
- The guard's state-write path makes no attacker-controlled external call.
- A rejected malformed or unauthenticated message does not latch the breaker.
  Only `RATE_LIMIT`, `VOLUME_SPIKE`, and an explicit policy `DENY` do.

## Identity resolution

`EnsIdentityRegistry` stores a DNS-encoded name for every approved ENS node.
It asks ENS Universal Resolver for that node's on-chain address record. A
missing allowlist entry, a failed resolution, malformed data, or a CCIP-Read
response resolves to `address(0)`, so the guard rejects the message. A source
therefore needs an on-chain address record that the configured resolver can
return in a static call.

## Operational limits

- The guardian can change configuration and clear the breaker. Production use
  should assign these powers to an appropriate operational control.
- The first `warmup` accepted messages for a source establish its local volume
  baseline. A volume oracle, when configured, replaces local volume checks.
- Policy and volume providers are trusted for availability and correct verdicts.
  If a policy is configured but has no current explicit `ALLOW`, settlement is
  held.
- The repository's deployments are testnet deployments and the contracts have
  not been independently audited.

## Testing evidence

The test suite includes unit tests, fuzzing, stateful invariants, and exploit
replays. Run it with `forge test`; the local walkthrough is `forge script
script/Demo.s.sol`.
