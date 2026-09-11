# Portcullis Guardian Dashboard

The dashboard is the operational view of the Sepolia Portcullis deployment. It
reads the circuit-breaker state directly from `PortcullisGuard` and displays
settlements, rejections, configuration, and breaker events indexed by the
subgraph. A connected guardian can submit `clear()` only when the contract
reports that account has the guardian role.

Public dashboard: <https://portcullis.b0gdaniy.xyz>.

## Run locally

```bash
npm install
npm run dev
npm run build
```

The app is a static Next.js export. It defaults to the public Sepolia
deployment and can be pointed at another deployment with these public
environment variables:

| Variable | Purpose |
| --- | --- |
| `NEXT_PUBLIC_PRIVY_APP_ID` | Privy application ID |
| `NEXT_PUBLIC_GUARD_ADDRESS` | `PortcullisGuard` address |
| `NEXT_PUBLIC_RECEIVER_ADDRESS` | Settlement receiver address |
| `NEXT_PUBLIC_SUBGRAPH_URL` | GraphQL query endpoint |
| `NEXT_PUBLIC_RPC_URL` | JSON-RPC endpoint |
| `NEXT_PUBLIC_CHAIN_ID` | Target chain ID |
| `NEXT_PUBLIC_EXPLORER` | Block-explorer base URL |

All `NEXT_PUBLIC_*` values are visible to browser users. Do not place private
keys or other secrets in them. Deployment addresses and explorer links are in
[`docs/deployments.md`](../../docs/deployments.md).
