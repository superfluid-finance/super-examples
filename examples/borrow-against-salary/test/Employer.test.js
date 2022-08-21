const { Framework } = require("@superfluid-finance/sdk-core")
const { assert } = require("chai")
const { ethers, network } = require("hardhat")
const LoanArtifact = require("../artifacts/contracts/EmploymentLoan.sol/EmploymentLoan.json")
const EmployerArtifact = require("../artifacts/contracts/Employer.sol/Employer.json")

const { deployFramework, deployWrapperSuperToken } = require("./util/deploy-sf")

let contractsFramework
let sf
let dai
let daix
let employee
let lender
let employer
let employerC

const alotOfEth = ethers.utils.parseEther("100000")

before(async function () {
    //get accounts from hardhat
    ;[admin, employee, lender, employer] = await ethers.getSigners()

    contractsFramework = await deployFramework(admin)

    //initialize the superfluid framework...put custom and web3 only bc we are using hardhat locally
    sf = await Framework.create({
        chainId: 31337,
        provider: admin.provider,
        resolverAddress: contractsFramework.resolver,
        protocolReleaseVersion: "test"
    })

    const tokenDeployment = await deployWrapperSuperToken(
        admin,
        contractsFramework.superTokenFactory,
        "fDAI",
        "fDAI"
    )

    dai = tokenDeployment.underlyingToken
    daix = tokenDeployment.superToken

    const Employer = await ethers.getContractFactory("Employer", employer)
    employerC = await Employer.deploy(
        daix.address,
        sf.settings.config.hostAddress
    )

    await employerC.deployed()

    await dai.mint(admin.address, alotOfEth)
    await dai.approve(daix.address, alotOfEth)
    await daix.upgrade(alotOfEth)
    await daix.transfer(employer.address, alotOfEth)

    await dai.mint(admin.address, alotOfEth)
    await dai.approve(daix.address, alotOfEth)
    await daix.upgrade(alotOfEth)
    await daix.transfer(employerC.address, alotOfEth)

    let employerFlowOperation = sf.cfaV1.createFlow({
        superToken: daix.address,
        receiver: employerC.address,
        flowRate: "1157407400000000" // ~100k per year in usd
    })

    await employerFlowOperation.exec(employer)
})

beforeEach(async function () {
    await dai.mint(admin.address, alotOfEth)

    await dai.mint(employer.address, alotOfEth)

    await dai.mint(lender.address, alotOfEth)

    await dai.approve(daix.address, alotOfEth)

    await dai.connect(employer).approve(daix.address, alotOfEth)

    await dai.connect(lender).approve(daix.address, alotOfEth)

    await daix.upgrade(alotOfEth)

    await daix.connect(employer).upgrade(alotOfEth)

    await daix.connect(lender).upgrade(alotOfEth)
})

describe("Employee Contract", async function () {
    it("add employee", async function () {
        await employerC.addEmployee(
            employee.address, // employee wallet
            2 // 1 DAI per day
        ).then(console.log)

        console.log(await employerC.totalPayrollFlowRate())
    })

    it("add 2nd employee", async function () {
        var wallet = ethers.Wallet.createRandom();
        console.log("Address: " + wallet.address);

        await employerC.addEmployee(
            wallet.address, // employee wallet
            1 // 1 DAI per day
        ).then(console.log)

        console.log(await employerC.totalPayrollFlowRate())
    })

    it("update employee", async function () {
        await employerC.updatePaymentFlow(
            1, // employeeId
            1 // 1 DAI per day
        ).then(console.log)

        console.log(await employerC.totalPayrollFlowRate())
    })

})
