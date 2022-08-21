const ethers = require("ethers")
const { Framework } = require("@superfluid-finance/sdk-core")
require("dotenv").config()

async function main() {
    //NOTE: this is set as the goerli url, but can be changed to reflect your RPC URL and network of choice
    const url = `${process.env.GOERLI_URL}`
    const customHttpProvider = new ethers.providers.JsonRpcProvider(url)

    const network = await customHttpProvider.getNetwork()

    const sf = await Framework.create({
        chainId: network.chainId,
        provider: customHttpProvider
    })

    const deployer = sf.createSigner({
        privateKey: process.env.EMPLOYER_PRIVATE_KEY, // deployer here doesn't matter much
        provider: customHttpProvider
    })

    //NOTE - this is DAIx on goerli - you can change this token to suit your network and desired token address
    const daix = await sf.loadSuperToken("fDAIx")

    console.log("running deploy script...")
    // We get the contract to deploy
    const Scoring = await hre.ethers.getContractFactory("Scoring")
    const scoring = await Scoring.connect(deployer).deploy(
        '0xA124387236E773435fa0f5F6FF2d54E3053D4c50'
    )

    await scoring.deployed()

    //NOTE: you will need this address to run other scripts, so we recommend getting it from the console
    console.log("Scoring.sol deployed to:", scoring.address)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })
