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
