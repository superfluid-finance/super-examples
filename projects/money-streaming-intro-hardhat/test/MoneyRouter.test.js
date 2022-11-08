const { expect } = require("chai")
const { Framework } = require("@superfluid-finance/sdk-core")
const { ethers } = require("hardhat")
const frameworkDeployer = require("@superfluid-finance/ethereum-contracts/scripts/deploy-test-framework")
const TestToken = require("@superfluid-finance/ethereum-contracts/build/contracts/TestToken.json")

let sfDeployer
let contractsFramework
let sf
let moneyRouter
let dai
let daix

// Test Accounts
let owner
let account1
let account2

const thousandEther = ethers.utils.parseEther("10000")

before(async function () {
    // get hardhat accounts
    ;[owner, account1, account2] = await ethers.getSigners()

    sfDeployer = await frameworkDeployer.deployTestFramework()

    // GETTING SUPERFLUID FRAMEWORK SET UP

    // deploy the framework locally
    contractsFramework = await sfDeployer.getFramework()

    // initialize framework
    sf = await Framework.create({
        chainId: 31337,
        provider: owner.provider,
        resolverAddress: contractsFramework.resolver, // (empty)
        protocolReleaseVersion: "test"
    })

    // DEPLOYING DAI and DAI wrapper super token
    tokenDeployment = await sfDeployer.deployWrapperSuperToken(
        "Fake DAI Token",
        "fDAI",
        18,
        ethers.utils.parseEther("100000000").toString()
    )

    daix = await sf.loadSuperToken("fDAIx")
    dai = new ethers.Contract(
        daix.underlyingToken.address,
        TestToken.abi,
        owner
    )
    // minting test DAI
    await dai.mint(owner.address, thousandEther)
    await dai.mint(account1.address, thousandEther)
    await dai.mint(account2.address, thousandEther)

    // approving DAIx to spend DAI (Super Token object is not an ethers contract object and has different operation syntax)
    await dai.approve(daix.address, ethers.constants.MaxInt256)
    await dai
        .connect(account1)
        .approve(daix.address, ethers.constants.MaxInt256)
    await dai
        .connect(account2)
        .approve(daix.address, ethers.constants.MaxInt256)
    // Upgrading all DAI to DAIx
    const ownerUpgrade = daix.upgrade({ amount: thousandEther })
    const account1Upgrade = daix.upgrade({ amount: thousandEther })
    const account2Upgrade = daix.upgrade({ amount: thousandEther })

    await ownerUpgrade.exec(owner)
    await account1Upgrade.exec(account1)
    await account2Upgrade.exec(account2)

    let MoneyRouter = await ethers.getContractFactory("MoneyRouter", owner)

    moneyRouter = await MoneyRouter.deploy(
        sf.settings.config.hostAddress,
        owner.address
    )
    await moneyRouter.deployed()
})

describe("Money Router", function () {
    it("Access Control #1 - Should deploy properly with the correct owner", async function () {
        expect(await moneyRouter.owner()).to.equal(owner.address)
    })
    it("Access Control #2 - Should allow you to add account to account list", async function () {
        await moneyRouter.allowAccount(account1.address)

        expect(await moneyRouter.accountList(account1.address), true)
    })
    it("Access Control #3 - Should allow for removing accounts from whitelist", async function () {
        await moneyRouter.removeAccount(account1.address)

        expect(await moneyRouter.accountList(account1.address), true)
    })
    it("Access Control #4 - Should allow for change in ownership", async function () {
        await moneyRouter.changeOwner(account1.address)

        expect(await moneyRouter.owner(), account1.address)
    })
    it("Contract Receives Funds #1 - lump sum is transferred to contract", async function () {
        //transfer ownership back to real owner...
        await moneyRouter.connect(account1).changeOwner(owner.address)

        await daix
            .approve({
                receiver: moneyRouter.address,
                amount: ethers.utils.parseEther("100")
            })
            .exec(owner)

        await moneyRouter.sendLumpSumToContract(
            daix.address,
            ethers.utils.parseEther("100")
        )

        let contractDAIxBalance = await daix.balanceOf({
            account: moneyRouter.address,
            providerOrSigner: owner
        })
        expect(contractDAIxBalance, ethers.utils.parseEther("100"))
    })
    it("Contract Receives Funds #2 - a flow is created into the contract", async function () {
        let authorizeContractOperation = sf.cfaV1.updateFlowOperatorPermissions(
            {
                superToken: daix.address,
                flowOperator: moneyRouter.address,
                permissions: "7", //full control
                flowRateAllowance: "1000000000000000" // ~2500 per month
            }
        )
        await authorizeContractOperation.exec(owner)

        await moneyRouter.createFlowIntoContract(
            daix.address,
            "100000000000000"
        ) //about 250 daix per month

        let ownerContractFlowRate = await sf.cfaV1.getFlow({
            superToken: daix.address,
            sender: owner.address,
            receiver: moneyRouter.address,
            providerOrSigner: owner
        })

        expect(ownerContractFlowRate, "100000000000000")
    })
    it("Contract recieves funds #3 - a flow into the contract is updated", async function () {
        await moneyRouter.updateFlowIntoContract(
            daix.address,
            "200000000000000"
        ) // about 250 daix per month

        let ownerContractFlowRate = await sf.cfaV1.getFlow({
            superToken: daix.address,
            sender: owner.address,
            receiver: moneyRouter.address,
            providerOrSigner: owner
        })

        expect(ownerContractFlowRate, "200000000000000")
    })
    it("Contract receives funds #4 - a flow into the contract is deleted", async function () {
        await moneyRouter.deleteFlowIntoContract(daix.address)

        let ownerContractFlowRate = await sf.cfaV1.getFlow({
            superToken: daix.address,
            sender: owner.address,
            receiver: moneyRouter.address,
            providerOrSigner: owner
        })

        expect(ownerContractFlowRate, "0")
    })
    it("Contract sends funds #1 - withdrawing a lump sum from the contract", async function () {
        let contractStartingBalance = await daix.balanceOf({
            account: moneyRouter.address,
            providerOrSigner: owner
        })

        await moneyRouter.withdrawFunds(
            daix.address,
            ethers.utils.parseEther("10")
        )

        let contractFinishingBalance = await daix.balanceOf({
            account: moneyRouter.address,
            providerOrSigner: owner
        })

        expect(Number(contractStartingBalance) - 10, contractFinishingBalance)
    })

    it("Contract sends funds #2 - creating a flow from the contract", async function () {
        await moneyRouter.createFlowFromContract(
            daix.address,
            account1.address,
            "100000000000000"
        ) //about 250 per month

        let receiverContractFlowRate = await sf.cfaV1.getFlow({
            superToken: daix.address,
            sender: account1.address,
            receiver: moneyRouter.address,
            providerOrSigner: owner
        })

        expect(receiverContractFlowRate, "100000000000000")
    })
    it("Contract sends funds #3 - updating a flow from the contract", async function () {
        await moneyRouter.updateFlowFromContract(
            daix.address,
            account1.address,
            "200000000000000"
        ) //about 500 per month

        let receiverContractFlowRate = await sf.cfaV1.getFlow({
            superToken: daix.address,
            sender: account1.address,
            receiver: moneyRouter.address,
            providerOrSigner: owner
        })

        expect(receiverContractFlowRate, "200000000000000")
    })
    it("Contract sends funds #3 - deleting a flow from the contract", async function () {
        await moneyRouter.deleteFlowFromContract(daix.address, account1.address) //about 500 per month

        let receiverContractFlowRate = await sf.cfaV1.getFlow({
            superToken: daix.address,
            sender: account1.address,
            receiver: moneyRouter.address,
            providerOrSigner: owner
        })

        expect(receiverContractFlowRate, "0")
    })
})
