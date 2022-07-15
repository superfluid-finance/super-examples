const ethers = require("ethers")
const { Framework } = require("@superfluid-finance/sdk-core")
const LoanContract = require("../artifacts/contracts/EmploymentLoan.sol/EmploymentLoan.json")
const { network } = require("hardhat")
const LoanContractABI = LoanContract.abi
require("dotenv").config()

//NOTE
//lender should call lend on the above contract using sdk

async function main() {
    const url = `${process.env.GOERLI_URL}`
    const customHttpProvider = new ethers.providers.JsonRpcProvider(url)

    const network = await customHttpProvider.getNetwork()

    const sf = await Framework.create({
        chainId: network.chainId,
        provider: customHttpProvider
    })

    //most recent loan address
    const loanAddress = "0x6E15Bf3b8Ac5f9C8B89C15197db008cEC9fFFCD6" //NOTE - must be updated to reflect actual loan address

    const lender = sf.createSigner({
        privateKey: process.env.LENDER_PRIVATE_KEY,
        provider: customHttpProvider
    })

    const employmentLoan = new ethers.Contract(
        loanAddress,
        LoanContractABI,
        lender
    )

    await employmentLoan
        .connect(lender)
        .lend()
        .then(tx => {
            console.log(tx)
        })
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })
