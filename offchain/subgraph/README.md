# Portcullis subgraph

This subgraph indexes `PortcullisGuard` and `ArcSettlementReceiver` events for
the Guardian Dashboard. It provides settlement verdicts, breaker transitions,
payouts, rejections, and current configuration through GraphQL.

## Data

`Settlement` records one guard verdict keyed by the settlement digest.
`SentinelEvent` records breaker transitions. `Payout` and `Rejection` record
the receiver outcome. `GuardConfig`, `Source`, and `AllowedToken` reflect
configuration events.

The public Sepolia query endpoint is:
<https://api.studio.thegraph.com/query/59239/portcullis/latest>.

## Build

```bash
npm install
npm run codegen
npm run build:sepolia
```

`networks.json` contains the indexed contract addresses and start blocks. The
ABIs under `abis/` are generated from the Foundry build output and must match
the deployed event interfaces.
