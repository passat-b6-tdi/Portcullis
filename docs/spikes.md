# Integration spikes

Four short spikes de-risked the sponsor integrations before they were wired
into the guard. Each answered one narrow feasibility question. None produced
production code by itself.

## Chainlink CRE (Confidential Workflows, TEE)

**Question:** can a TEE workflow sign a payload that an EVM contract can
verify on-chain?

Deploy access to CRE Confidential Workflows was not available at spike time.
Enrollment in Chainlink's private beta requires manual approval from the
account team. The spike remained a documented design. `ISentinelOracle` /
`CrePolicyConsumer` defines the on-chain shape a verdict report must have
(`msgHash`, `verdict`, `riskMask`, `issuedAt`). `MockVerdictOracle`
implements the same interface, so tests fully exercise the guard's policy
path without a live workflow. `cre workflow simulate` against the real
`policy/` workflow (sanctions check + velocity check inside a TEE handler)
passes locally. Deploy access was granted after the spike window; the actual
`cre workflow deploy` follows once the workflow's public HTTP dependencies
are reachable (see `offchain/cre-workflow/README.md`).

## ENSv2 (Sepolia)

**Question:** register a subname, wire a permissioned or wildcard resolver,
and read an address record from a contract.

Confirmed on Sepolia against the deployed `UniversalResolverV2` proxy
(`0xeEeEEEeE14D718C2B47D9923Deab1335E144EeEe`). `EnsIdentityRegistry` calls
`universalResolver.resolve(name, abi.encodeCall(addr,(node)))` in a
`try/catch`, returning `address(0)` on any revert, including an
`OffchainLookup` from CCIP-Read, which cannot be followed from a `view`
`STATICCALL`. A guardian allowlists `node → DNS-encoded name` explicitly
(`allow`/`allowBatch`/`revoke`). Resolution is otherwise open to any name
with a resolver, mirroring the trust boundary documented in
`docs/security-notes.md`. `portcullis-src.eth` is registered on Sepolia with
an ETH address record pointing at the source authority used in the live
demo.

## Arc testnet

**Question:** faucet, RPC, and a hello-world deploy.

Circle's own `rpc.testnet.arc.network` endpoint geo-blocks Ukraine-based
requests (Cloudflare error 1009); `https://arc-testnet.rpc.thirdweb.com`
works and is the RPC configured throughout this repository. Faucet and a
minimal deployment both succeeded without further issues. Arc mainnet opens
2026-09-16, the same day as the ETHOnline submission deadline.

## Hedera HTS

**Question:** deploy a minimal contract that calls HTS `mintToken` through
the `0x167` precompile, and mint to a **third** address instead of only the
deployer.

This spike was expected to gate a whole architecture layer. An early design
used a Hedera-minted "Settlement Receipt" token as an audit trail for every
cleared settlement. HTS requires the receiving address to
call `associateToken` before it can receive a token; minting to a treasury
the receiver contract itself controls would have worked around that with a
one-time self-association at deploy time, but the layer added a second hop
that the firewall itself does not protect. A compromised or delayed Hedera
mint doesn't block the underlying settlement, and the layer added no new detector.
Hedera's listed ETHOnline 2026 bounty rewards a broader "Tokenization of
Anything" story. It does not specifically reward an audit-trail token. The layer was cut before implementation.
The final architecture uses on-chain events plus The Graph for the audit
trail instead. Nothing in this repository depends on Hedera.

## Outcome

| Spike | Result |
| --- | --- |
| Chainlink CRE | Documented design + `MockVerdictOracle`; real deploy follows this spike, gated on org deploy access (since granted) |
| ENSv2 | Shipped as `EnsIdentityRegistry`, live on Sepolia |
| Arc | Shipped as the settlement origination chain |
| Hedera | Cut before implementation; not part of the shipped architecture |
