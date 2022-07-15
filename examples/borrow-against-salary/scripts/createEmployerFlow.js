const ethers = require("ethers")
const { Framework } = require("@superfluid-finance/sdk-core")
require("dotenv").config()
//here is where you'll put your loan address that you'll be interacting with
const loanAddress = "0x929B0e95f612461458bDA45D50590399443738A8"

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

    const employerFlowOperation = sf.cfaV1.createFlow({
        receiver: loanAddress,
        flowRate: "3858024691358024", //10k per month
        superToken: daix.address
    })

    console.log("running create flow script...")

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
