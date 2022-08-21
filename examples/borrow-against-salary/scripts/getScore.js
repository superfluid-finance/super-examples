const ethers = require("ethers")
const { Framework } = require("@superfluid-finance/sdk-core")
const scoringABI =
    require("../artifacts/contracts/Scoring.sol/Scoring.json").abi

const scoringAddress = "0x9aAA24DBf6f05c7620Fa9c69abE9A9da44b01577";
const borrowerAddress = "0x66Ca33c8fb6A6203CeD1708de4a044A5214d0860";

async function main() {
    const url = `${process.env.GOERLI_URL}`
    const customHttpProvider = new ethers.providers.JsonRpcProvider(url)
    const network = await customHttpProvider.getNetwork()

    scoring = new ethers.Contract(
        scoringAddress,
        scoringABI,
        customHttpProvider
    );

    // const sf = await Framework.create({
    //     chainId: network.chainId,
    //     provider: customHttpProvider
    // })

    // const lender = sf.createSigner({
    //     privateKey: process.env.LENDER_PRIVATE_KEY,
    //     provider: customHttpProvider
    // })


    console.log("running transfer operation...");
    await scoring.getScore(borrowerAddress)
    .then(tx => {
        console.log(
            "borrower score is: ",
            tx
        )
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

