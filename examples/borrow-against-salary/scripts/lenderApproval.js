//most recent loan address
const loanAddress = "0x929B0e95f612461458bDA45D50590399443738A8" //NOTE - update w actual loan address
const ethers = require("ethers")
const { Framework } = require("@superfluid-finance/sdk-core")
const LoanContract = require("../artifacts/contracts/EmploymentLoan.sol/EmploymentLoan.json")
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

    const lender = sf.createSigner({
        privateKey: process.env.LENDER_PRIVATE_KEY,
        provider: customHttpProvider
    })

    const daix = await sf.loadSuperToken("fDAIx")

    const employmentLoan = new ethers.Contract(
        loanAddress,
        LoanContractABI,
        lender
    )

    const borrowAmount = await employmentLoan.borrowAmount()

    const lenderBalance = await daix.balanceOf({
        account: lender.address,
        providerOrSigner: lender
    })

    const lenderApprovalOperation = daix.approve({
        receiver: employmentLoan.address,
        amount: borrowAmount
    })

    await lenderApprovalOperation.exec(lender).then(tx => {
        console.log(tx)
    })
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })
