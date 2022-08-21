const { Framework } = require("@superfluid-finance/sdk-core")
const { assert } = require("chai")
const { ethers, network } = require("hardhat")
const LoanArtifact = require("../artifacts/contracts/EmploymentLoan.sol/EmploymentLoan.json")
const ScoringArtifact = require("../artifacts/contracts/Scoring.sol/Scoring.json")

const { deployFramework, deployWrapperSuperToken } = require("./util/deploy-sf")

let contractsFramework
let sf
let dai
let daix
let borrower
let lender
let employer
let loanFactory
let employmentLoan
let scoring

const alotOfEth = ethers.utils.parseEther("100000")

before(async function () {
    //get accounts from hardhat
    ;[admin, borrower, lender, employer] = await ethers.getSigners()

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

    const LoanFactory = await ethers.getContractFactory("LoanFactory", admin)
    loanFactory = await LoanFactory.deploy()

    await loanFactory.deployed()

    console.log(loanFactory.address)

    const Scoring = await ethers.getContractFactory("Scoring", admin)
    scoring = await Scoring.deploy(loanFactory.address)

    await scoring.deployed()

    console.log(scoring.address)
    console.log(await scoring.factoryAddress())

    let borrowAmount = ethers.utils.parseEther("1000")
    let interest = 10
    let paybackMonths = 12

    await loanFactory.createNewLoan(
        borrowAmount, //borrowing 1000 fDAI tokens
        interest, // 10% annual interest
        paybackMonths, //in months
        employer.address, //address of employer
        borrower.address, //address of borrower
        daix.address,
        sf.settings.config.hostAddress
    )

    let loanAddress = await loanFactory.idToLoan(1)

    employmentLoan = new ethers.Contract(loanAddress, LoanArtifact.abi, admin)
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

    await daix.transfer(employmentLoan.address, alotOfEth)
})

describe("scoring loans", async function () {
    it("calculate score with existing address", async function () {
        await borrower.address
        score = await scoring.getScore(borrower.address);

        assert.equal(score, 1)
    })

    it("calculate score with non existent address", async function () {
        await borrower.address

        var wallet = ethers.Wallet.createRandom();
        console.log("Address: " + wallet.address);

        score = await scoring.getScore(wallet.address);

        assert.equal(score, 0)
    })
})
