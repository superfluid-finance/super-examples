// streams WATERx tokens from your wallet into the Flower NFT contract (you're minted a Flower NFT as a result)

const hre = require("hardhat")
const { ethers } = require("hardhat")
const { Framework } = require("@superfluid-finance/sdk-core")
const deployedContracts = require("./utils/deployedContracts")

async function main() {
    const url = `${process.env.MUMBAI_URL}`
    const customHttpProvider = new ethers.providers.JsonRpcProvider(url)
    customHttpProvider.chai

    const sf = await Framework.create({
        chainId: 80001,
        provider: customHttpProvider,
        customSubgraphQueriesEndpoint: "",
        dataMode: "WEB3_ONLY"
    })

    const signer = await hre.ethers.getSigner()

    const createFlowOp = sf.cfaV1.createFlow({
        superToken: deployedContracts.superWater.address,
        sender: signer.address,
        receiver: deployedContracts.flower.address,
        flowRate: "83333333333333330" // 10 WATERx / 2 min
    })

    const updateFlowOp = sf.cfaV1.updateFlow({
        superToken: deployedContracts.superWater.address,
        sender: signer.address,
        receiver: deployedContracts.flower.address,
        flowRate: "41666666666666664" // 10 WATERx / 4 min
    })

    const deleteFlowOp = sf.cfaV1.deleteFlow({
        superToken: deployedContracts.superWater.address,
        sender: signer.address,
        receiver: deployedContracts.flower.address
    })

    let selectedOp = deleteFlowOp // NOTE: set flow operation you want here!

    let tx = await selectedOp.exec(signer)
    await tx.wait()

    console.log(`Stream operation successfully performed!`)
    console.log(
        `Head to https://console.superfluid.finance and search the Flower NFT address at`,
        deployedContracts.flower.address,
        `to see the results of the modification`
    )
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
    console.error(error)
    process.exitCode = 1
})
