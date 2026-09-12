# Portcullis policy workflow

This Chainlink CRE workflow evaluates a pending settlement against a private
policy and pushes its result to `CrePolicyConsumer`. The guard reads the stored
verdict before it accepts a settlement when this policy is configured.

The report payload is `abi.encode(bytes32 msgHash, uint8 verdict, uint8
riskMask, uint64 issuedAt)`. `msgHash` must be the same chain- and guard-bound
digest returned by `PortcullisGuard.digestOf`.

Verdict codes are `1` for `ALLOW`, `2` for `DENY`, and `3` for
`MANUAL_REVIEW`. The guard accepts only an explicit `ALLOW`.

## Local simulation

```bash
cd policy
bun install
cp ../.env.example ../.env
SECRET_SANCTIONS_API_KEY=dev-sanctions-key MOCK_PORT=4600 node mock-server.js &
cd ..
cre workflow simulate ./policy --target=staging-settings --env ./.env
```

Run `bun test` from `policy/` for the workflow tests. `.env` is local-only;
keep credentials out of the repository.

## Deployment

`policy/config.staging.json` points `pendingUrl`/`sanctionsUrl` at
`https://passat-b6-tdi.github.io/Portcullis/mock/policy-{pending,sanctions}.json`.
A deployed workflow runs on DON nodes in Chainlink's infrastructure and cannot
reach the local mock server used for `cre workflow simulate`. The two static
JSON files in `docs/mock/` serve the same fake settlement data as
`policy/mock-server.js`. They are published through the repository's GitHub
Pages site (`docs/`), with no separate hosting account or billing dependency.
Static hosting cannot check an `Authorization` header. These endpoints are
unauthenticated, while the workflow still sends
`Authorization: Bearer <SECRET_SANCTIONS_API_KEY>` and the static host ignores
it. The underlying data is fake demo data, not a real sanctions list.

An earlier iteration served these from Netlify Functions on the dashboard's
own site (`offchain/dashboard/netlify/functions/`). That path remains and
works once the Netlify team's production deploys are unpaused. GitHub Pages is
the deploy target while they are paused.

```bash
cre workflow deploy ./policy --target=staging-settings --env ./.env
```
