const ethers = require("ethers")
const { Framework } = require("@superfluid-finance/sdk-core")
const LoanFactoryABI =
    require("../artifacts/contracts/LoanFactory.sol/LoanFactory.json").abi
require("dotenv").config()

//place deployed address of the loan factory here...
const LoanFactoryAddress = "0xd75B13429C84a6d7b3f056cE262938A4f7Bd5053"

//place the ID of your loan here. Note that loanIds start at 1
const LoanId = 1
//NOTE: this is set as the goerli url, but can be changed to reflect your RPC URL and network of choice
const url = process.env.GOERLI_URL

const customHttpProvider = new ethers.providers.JsonRpcProvider(url)

async function main() {
    const network = await customHttpProvider.getNetwork()

    const sf = await Framework.create({
        chainId: network.chainId,
        provider: customHttpProvider
    })

    const loanFactory = new ethers.Contract(
        LoanFactoryAddress,
        LoanFactoryABI,
        customHttpProvider
    )

    const loanAddress = await loanFactory.getLoanAddressByID(LoanId)

    console.log(`The address of loan ${LoanId} is ${loanAddress}`)
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })
