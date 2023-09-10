const hre = require("hardhat")
const { Framework } = require("@superfluid-finance/sdk-core")
const { ethers, providers } = require("ethers")
require("dotenv")

async function main() {
    const url = `${process.env.GOERLI_RPC_URL}`
    const customHttpProvider = new ethers.providers.JsonRpcProvider(url)

    const sf = await Framework.create({
        chainId: 5,
        provider: customHttpProvider,
        customSubgraphQueriesEndpoint: "",
        dataMode: "WEB3_ONLY"
    })

    const signer = sf.createSigner({
        privateKey: process.env.DEPLOYER_PRIVATE_KEY,
        provider: customHttpProvider
    })

    const daix = await sf.loadSuperToken("fDAIx")

    const createFlowOperation = daix.createFlow({
        receiver: "ADDRESS", //tradeable cashflow address
        flowRate: "100000000000"
    })

    const txn = await createFlowOperation.exec(signer)

    const receipt = await txn.wait()

    console.log(receipt)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })
