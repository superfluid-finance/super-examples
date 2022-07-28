//most recent loan address
const ethers = require("ethers")
const { Framework } = require("@superfluid-finance/sdk-core")
require("dotenv").config()

const loanAddress = "" //NOTE: must change to reflect actual loan address

//NOTE - this should be run first to ensure that the contract has a small token balance

async function main() {
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

    const borrower = sf.createSigner({
        privateKey: process.env.BORROWER_PRIVATE_KEY,
        provider: customHttpProvider
    })

    const daix = await sf.loadSuperToken("fDAIx")

    const transferAmount = ethers.utils.parseEther("100")

    const borrowerTransferOperation = daix.transfer({
        receiver: loanAddress,
        amount: transferAmount // 100 dai
    })

    console.log("running transfer operation...")

    await borrowerTransferOperation.exec(borrower).then(console.log)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })
