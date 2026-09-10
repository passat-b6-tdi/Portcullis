set dotenv-load := false

account := "deployer"

# address of the keystore account (prompts for password)
addr:
    cast wallet address --account {{account}}

build:
    forge build

test:
    forge test

fmt:
    forge fmt

demo:
    forge script script/Demo.s.sol

# deploy core (guard + address-book registry) to a network
# prepend IDENTITY=0x.. to point the guard at a pre-deployed registry instead
deploy-core network sender:
    forge script script/DeployCore.s.sol:DeployCore \
        --rpc-url {{network}} --account {{account}} --sender {{sender}} --broadcast

# deploy the settlement receiver (ArcSettlementReceiver) to a network
deploy-receiver network guard sender:
    GUARD={{guard}} forge script script/DeployArc.s.sol:DeployArc \
        --rpc-url {{network}} --account {{account}} --sender {{sender}} --broadcast

# deploy the CRE policy consumer and wire it (GUARD + CRE_FORWARDER env)
# arc-testnet forwarder: 0x76c9cf548b4179F8901cda1f8623568b58215E62
deploy-cre guard forwarder sender:
    GUARD={{guard}} CRE_FORWARDER={{forwarder}} forge script script/DeployCre.s.sol:DeployCre \
        --rpc-url arc_testnet --account {{account}} --sender {{sender}} --broadcast

# deploy a mock 6-dec USDC to a network and pre-fund the receiver
deploy-usdc network receiver sender:
    RECEIVER={{receiver}} forge script script/DeployMockUsdc.s.sol:DeployMockUsdc \
        --rpc-url {{network}} --account {{account}} --sender {{sender}} --broadcast

# live end-to-end smoke test on any network. env: GUARD, RECEIVER, TOKEN, AUTHORITY_PK
# (CONSUMER, RECIPIENT, VALUE, SRC_ID optional)
smoke network sender:
    forge script script/SmokeArc.s.sol:SmokeArc \
        --rpc-url {{network}} --account {{account}} --sender {{sender}} --broadcast

# fire 10 varied settlements (PASS/EXPIRED/BOUNDS/BINDING/NONCE_GAP/REPLAY) for the
# dashboard feed. env: GUARD, RECEIVER, TOKEN, AUTHORITY_PK (SRC_ID, RECIPIENT opt)
seed-feed network sender:
    forge script script/SeedFeed.s.sol:SeedFeed \
        --rpc-url {{network}} --account {{account}} --sender {{sender}} --broadcast

# live end-to-end smoke test of the Arc deployment (needs AUTHORITY_PK env)
smoke-arc sender:
    GUARD=0x100FEb2D822CBb32C4e8f047D43615AC8851Ed79 \
    RECEIVER=0x21e633FAE68838d3B517EBE72f4d01b18dC2b815 \
    TOKEN=0xf36BE8463c25e9AA235185dfbe344Fc486Ba7889 \
    CONSUMER=0xCAD48E5C29A0d243e7Fd5d56dEf0a6802B45f104 \
        forge script script/SmokeArc.s.sol:SmokeArc \
        --rpc-url arc_testnet --account {{account}} --sender {{sender}} --broadcast

# deploy the ENSv2 identity registry to Sepolia
deploy-ens sender:
    forge script script/DeployEns.s.sol:DeployEns \
        --rpc-url sepolia --account {{account}} --sender {{sender}} --broadcast

# offline: NAME=treasury.acme.eth -> namehash (ENS_NODE) + DNS wire (ENS_DNS_NAME)
ens-encode name:
    NAME={{name}} forge script script/EnsTools.s.sol:DnsEncode

# read-only: prove ENSv2 resolution via UniversalResolverV2 (REGISTRY + ENS_NODE env)
ens-resolve registry node:
    REGISTRY={{registry}} ENS_NODE={{node}} forge script script/EnsTools.s.sol:ResolveEns \
        --rpc-url sepolia

# configure a source on the guard. env: GUARD (required)
# AddressBook path: REGISTRY + SRC_AUTHORITY. ENS path: leave both unset, pass SRC_ID = ENS namehash.
# optional env: ALLOW_TOKEN + ALLOW_TOKEN_DECIMALS, ADAPTER, POLICY, SRC_ID
configure network guard sender:
    GUARD={{guard}} \
        forge script script/ConfigureGuard.s.sol:ConfigureGuard \
        --rpc-url {{network}} --account {{account}} --sender {{sender}} --broadcast
