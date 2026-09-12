# Deployments

These are testnet deployments. Verify the Sepolia contracts and transactions
through the links below. The deployment receipts are also retained under
`broadcast/`.

## Sepolia (chain ID 11155111)

| Contract | Address | Deployment transaction |
| --- | --- | --- |
| `EnsIdentityRegistry` | [`0xB99B…95da`](https://sepolia.etherscan.io/address/0xB99B7a11B0e6BF8F0220f7C4E9Bd5BA37d195da5) | [`0x64b7…df7f`](https://sepolia.etherscan.io/tx/0x64b7b5571abf38406b6cf6846ed8e48ee0261756043fa8f5936e851a4877df7f) |
| `PortcullisGuard` | [`0xE594…7008`](https://sepolia.etherscan.io/address/0xE59474b146d750022c5E3C9376d74D0Ca31D7008) | [`0x5037…7bd0`](https://sepolia.etherscan.io/tx/0x5037f0f803a87ce00ab3ab8eaecc669f519e5e460277ae361696bf1c24677bd0) |
| `ArcSettlementReceiver` | [`0x48a0…55B9`](https://sepolia.etherscan.io/address/0x48a04458bB4EaaD6D4902D30fFd8C20B6D2c55B9) | [`0x0f24…0d63`](https://sepolia.etherscan.io/tx/0x0f2443e9b46c85b68db96a4e98b00efa9b40058041ee77f62514f85945440d63) |
| `MockERC20` (USDC, 6 decimals) | [`0x432e…a5f7`](https://sepolia.etherscan.io/address/0x432ec79d4277B83b6dBBb3ea3Acb50627edaa5f7) | [`0xea7c…277b`](https://sepolia.etherscan.io/tx/0xea7cd27407dec5b7b2f529f56aae62c4b427de880b2427e54be9d0c8865e277b) |

The subgraph starts indexing the guard at block `11674746` and the receiver at
block `11674752`. Query it at
[`portcullis`](https://api.studio.thegraph.com/query/59239/portcullis/latest).

The recorded Sepolia smoke run includes a genuine settlement transaction:
[`0xf7c0…ead83`](https://sepolia.etherscan.io/tx/0xf7c0209efb569f1539012c2b2855c81b0c7545f20ef6296dceed0d3eee7ead83).

## Arc testnet (chain ID 5042002)

| Contract | Address | Deployment transaction |
| --- | --- | --- |
| `PortcullisGuard` | `0x100FEb2D822CBb32C4e8f047D43615AC8851Ed79` | `0xfc0574168015cf56761302b4269b1ea43f7c44075ab795f9099dc8e4443bc670` |
| `AddressBookRegistry` | `0xaDcDaBD5b96Af2c89829128321d913CF939d8604` | `0xe0d5cea465c20a07769eb57f44dc6cc3dbcbf5b3cf6dab5e1102956d0e2a73d0` |
| `ArcSettlementReceiver` | `0x21e633FAE68838d3B517EBE72f4d01b18dC2b815` | `0x219d3e4bb63cbaa8c47c917ea33dc8c626a1ed8521ffde6c424b2a10f9ef9c4d` |
| `MockERC20` (USDC, 6 decimals) | `0xf36BE8463c25e9AA235185dfbe344Fc486Ba7889` | `0x1a8fda80d60f6f2b4871b5149fbcafb0e61e41988c4e09a63fa030e8e04a71f6` |
| `CrePolicyConsumer` | `0xCAD48E5C29A0d243e7Fd5d56dEf0a6802B45f104` | `0x32fb231d796a5cb7dbec1e93ae297429cedf660fc03ead96314947c14f1ed02a` |

The Arc receipt files are available in `broadcast/Deploy*.s.sol/5042002/`.
The public RPC configured for this repository is
`https://arc-testnet.rpc.thirdweb.com`.

## Chainlink CRE policy workflow

`portcullis-policy-staging` is deployed to the CRE Workflow Registry on
Ethereum mainnet (registry is the ownership/registration ledger; the
workflow itself executes against Arc testnet, evaluating settlements for
`CrePolicyConsumer` there). Deploy transaction:
[`0x1638…9a8d3`](https://etherscan.io/tx/0x1638764a552badca5e1d6364478c722bfb2d9ebedfe94b772ca3533515d9a8d3).

| Field | Value |
| --- | --- |
| Workflow ID | `005b50e9b3847b16405663ce6d1dc5f29583a97c21341bbd399c701c30c81275` |
| Registry contract | `0x4Ac54353FA4Fa961AfcC5ec4B118596d3305E7e5` (ethereum-mainnet) |
| DON family | `zone-a` |
| Owner | `0x811AE8434b584dfde82C14102820570611d47A59` |

The workflow polls the fake pending-settlement and sanctions data at
`docs/mock/` (served over GitHub Pages, see `offchain/cre-workflow/README.md`)
every minute inside a TEE and reports a verdict to `CrePolicyConsumer` on
Arc.

## Dashboard

The public dashboard reads the Sepolia guard and subgraph:
<https://portcullis.b0gdaniy.xyz>.
