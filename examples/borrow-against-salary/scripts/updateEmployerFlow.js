const ethers = require("ethers")
const { Framework } = require("@superfluid-finance/sdk-core")
require("dotenv").config()
//here is where you'll put your loan address that you'll be interacting with
const loanAddress = "0x6E15Bf3b8Ac5f9C8B89C15197db008cEC9fFFCD6"

async function main() {
    //note - make sure that the proper URL is added
    const url = `${process.env.GOERLI_URL}`
    const customHttpProvider = new ethers.providers.JsonRpcProvider(url)

    const network = await customHttpProvider.getNetwork()
    const sf = await Framework.create({
        chainId: network.chainId,
        provider: customHttpProvider
    })

    const employer = sf.createSigner({
        privateKey: process.env.EMPLOYER_PRIVATE_KEY,
        provider: customHttpProvider
    })

    const daix = await sf.loadSuperToken("fDAIx")

    const employerFlowOperation = sf.cfaV1.updateFlow({
        receiver: loanAddress,
        flowRate: "2858024691358024",
        superToken: daix.address
    })

    console.log("running update flow script...")

    await employerFlowOperation.exec(employer).then(tx => {
        console.log("Your tx succeeded!")
        console.log(tx)
    })
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })
