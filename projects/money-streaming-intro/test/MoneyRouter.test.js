const { Framework } = require("@superfluid-finance/sdk-core")
const { expect } = require("chai")
const { ethers } = require("hardhat")

const { deployFramework, deployWrapperSuperToken } = require("./util/deploy-sf")

let contractsFramework
let sf
let dai
let daix
let owner
let account1
let account2
let moneyRouter

const tenKEther = ethers.utils.parseEther("10000")

before(async function () {
    //get accounts from hardhat
    ;[owner, account1, account2] = await ethers.getSigners()

    //deploy the framework
    contractsFramework = await deployFramework(owner)

    const tokenPair = await deployWrapperSuperToken(
        owner,
        contractsFramework.superTokenFactory,
        "fDAI",
        "fDAI"
    )

    dai = tokenPair.underlyingToken
    daix = tokenPair.superToken

    // initialize the superfluid framework...put custom and web3 only bc we are using hardhat locally
    sf = await Framework.create({
        chainId: 31337,
        provider: owner.provider,
        resolverAddress: contractsFramework.resolver, //this is how you get the resolver address
        protocolReleaseVersion: "test"
    })

    let MoneyRouter = await ethers.getContractFactory("MoneyRouter", owner)

    moneyRouter = await MoneyRouter.deploy(
        sf.settings.config.hostAddress,
        owner.address
    )
    await moneyRouter.deployed()
})

beforeEach(async function () {
    await dai.mint(owner.address, tenKEther)

    await dai.mint(account1.address, tenKEther)

    await dai.mint(account2.address, tenKEther)

    await dai.connect(owner).approve(daix.address, tenKEther)
    await dai.connect(account1).approve(daix.address, tenKEther)
    await dai.connect(account2).approve(daix.address, tenKEther)

    await daix.upgrade(tenKEther)
    await daix.connect(account1).upgrade(tenKEther)
    await daix.connect(account2).upgrade(tenKEther)
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

        await daix.approve(moneyRouter.address, ethers.utils.parseEther("100"))
        await moneyRouter.sendLumpSumToContract(
            daix.address,
            ethers.utils.parseEther("100")
        )

        let contractDAIxBalance = await daix.balanceOf(moneyRouter.address)
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
        let contractStartingBalance = await daix.balanceOf(moneyRouter.address)

        await moneyRouter.withdrawFunds(
            daix.address,
            ethers.utils.parseEther("10")
        )

        let contractFinishingBalance = await daix.balanceOf(moneyRouter.address)

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
