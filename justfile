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
deploy-core network sender:
    forge script script/DeployCore.s.sol:DeployCore \
        --rpc-url {{network}} --account {{account}} --sender {{sender}} --broadcast

# deploy the Arc settlement receiver (GUARD env = guard address)
deploy-arc guard sender:
    GUARD={{guard}} forge script script/DeployArc.s.sol:DeployArc \
        --rpc-url arc_testnet --account {{account}} --sender {{sender}} --broadcast

# deploy the CRE policy consumer and wire it (GUARD + CRE_SIGNER env)
deploy-cre guard signer sender:
    GUARD={{guard}} CRE_SIGNER={{signer}} forge script script/DeployCre.s.sol:DeployCre \
        --rpc-url arc_testnet --account {{account}} --sender {{sender}} --broadcast
