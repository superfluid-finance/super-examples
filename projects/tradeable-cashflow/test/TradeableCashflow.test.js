const { expect } = require("chai")
const { Framework } = require("@superfluid-finance/sdk-core")
const { ethers } = require("hardhat")
const { deployTestFramework } = require("@superfluid-finance/ethereum-contracts/dev-scripts/deploy-test-framework");
const TestToken = require("@superfluid-finance/ethereum-contracts/build/contracts/TestToken.json")

let provider;
let accounts

let sfDeployer
let contractsFramework
let owner

let sf
let dai
let daix
let superSigner
let TradeableCashflow

const thousandEther = ethers.utils.parseEther("10000")

before(async function () {
    //get accounts from hardhat
    accounts = await ethers.getSigners()
    provider = accounts[0].provider;
    sfDeployer = await deployTestFramework()

    // GETTING SUPERFLUID FRAMEWORK SET UP

    // deploy the framework locally
    console.log("sfDeployer", sfDeployer.frameworkDeployer)

    contractsFramework = await sfDeployer.frameworkDeployer.getFramework()

    //initialize the superfluid framework...put custom and web3 only bc we are usinghardhat locally
    sf = await Framework.create({
        chainId: 31337, //note: this is hardhat's local chainId
        provider,
        resolverAddress: contractsFramework.resolver, //this is how you get the resolveraddress
        protocolReleaseVersion: "test"
    })

    // DEPLOYING DAI and DAI wrapper super token
    tokenDeployment = await sfDeployer.superTokenDeployer.deployWrapperSuperToken(
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

    //note: this is not totally necessary. you can just as easily use an ethers signer to execute ops
    superSigner = sf.createSigner({
        signer: accounts[0],
        provider: provider
    })

    //use the framework to get the super toen
    daix = await sf.loadSuperToken("fDAIx");
    dai = new ethers.Contract(
        daix.underlyingToken.address,
        TestToken.abi,
        owner
    )

    //get the contract object for the erc20 token
    // let daiAddress = daix.underlyingToken.address
    // dai = new ethers.Contract(daiAddress, daiABI, accounts[0])
    let App = await ethers.getContractFactory("TradeableCashflow", accounts[0])

    TradeableCashflow = await App.deploy(
        accounts[1].address,
        "TradeableCashflow",
        "TCF",
        sf.settings.config.hostAddress,
        sf.settings.config.cfaV1Address,
        daix.address
    )
})

beforeEach(async function () {
    // minting test DAI
    await dai.connect(accounts[0]).mint(accounts[0].address, thousandEther)
    await dai.connect(accounts[1]).mint(accounts[1].address, thousandEther)
    await dai.connect(accounts[2]).mint(accounts[2].address, thousandEther)
    
    // approving DAIx to spend DAI (Super Token object is not an etherscontract object and has different operation syntax)
    await dai.connect(accounts[0]).approve(daix.address, ethers.constants.MaxInt256)
    await dai.connect(accounts[1]).approve(daix.address, ethers.constants.MaxInt256)
    await dai.connect(accounts[2]).approve(daix.address, ethers.constants.MaxInt256)
    // Upgrading all DAI to DAIx
    const ownerUpgrade = daix.upgrade({ amount: thousandEther })
    const account1Upgrade = daix.upgrade({ amount: thousandEther })
    const account2Upgrade = daix.upgrade({ amount: thousandEther })
    
    await ownerUpgrade.exec(accounts[0])
    await account1Upgrade.exec(accounts[1])
    await account2Upgrade.exec(accounts[2])

    const daiBal = await daix.balanceOf({
        account: accounts[0].address,
        providerOrSigner: accounts[0]
    })
    console.log("daix bal for acct 0: ", daiBal)
})

describe("sending flows", async function () {
    it("Case #1 - Alice sends a flow", async () => {
        console.log(TradeableCashflow.address)

        const appInitialBalance = await daix.balanceOf({
            account: TradeableCashflow.address,
            providerOrSigner: accounts[0]
        })

        const createFlowOperation = daix.createFlow({
            receiver: TradeableCashflow.address,
            flowRate: "100000000"
        })

        const txn = await createFlowOperation.exec(accounts[0])

        await txn.wait()

        const appFlowRate = await daix.getNetFlow({
            account: TradeableCashflow.address,
            providerOrSigner: superSigner
        })

        const ownerFlowRate = await daix.getNetFlow({
            account: accounts[1].address,
            providerOrSigner: superSigner
        })

        const appFinalBalance = await daix.balanceOf({
            account: TradeableCashflow.address,
            providerOrSigner: superSigner
        })

        assert.equal(
            ownerFlowRate,
            "100000000",
            "owner not receiving 100% of flowRate"
        )

        assert.equal(appFlowRate, 0, "App flowRate not zero")

        assert.equal(
            appInitialBalance.toString(),
            appFinalBalance.toString(),
            "balances aren't equal"
        )
    })

    it("Case #2 - Alice upates flows to the contract", async () => {
        const appInitialBalance = await daix.balanceOf({
            account: TradeableCashflow.address,
            providerOrSigner: accounts[0]
        })

        const initialOwnerFlowRate = await daix.getNetFlow({
            account: accounts[1].address,
            providerOrSigner: superSigner
        })

        console.log("initial owner flow rate: ", initialOwnerFlowRate)

        const appFlowRate = await daix.getNetFlow({
            account: TradeableCashflow.address,
            providerOrSigner: superSigner
        })

        const senderFlowRate = await daix.getNetFlow({
            account: accounts[0].address,
            providerOrSigner: superSigner
        })
        console.log("sender flow rate: ", senderFlowRate)
        console.log("tcf address: ", TradeableCashflow.address)
        console.log("app flow rate: ", appFlowRate)

        const updateFlowOperation = daix.updateFlow({
            receiver: TradeableCashflow.address,
            flowRate: "200000000"
        })

        const updateFlowTxn = await updateFlowOperation.exec(accounts[0])

        await updateFlowTxn.wait()

        const appFinalBalance = await daix.balanceOf({
            account: TradeableCashflow.address,
            providerOrSigner: superSigner
        })

        const updatedOwnerFlowRate = await daix.getNetFlow({
            account: accounts[1].address,
            providerOrSigner: superSigner
        })

        assert.equal(
            updatedOwnerFlowRate,
            "200000000",
            "owner not receiving correct updated flowRate"
        )

        assert.equal(appFlowRate, 0, "App flowRate not zero")

        assert.equal(
            appInitialBalance.toString(),
            appFinalBalance.toString(),
            "balances aren't equal"
        )
    })

    it("Case 3: multiple users send flows into contract", async () => {
        const appInitialBalance = await daix.balanceOf({
            account: TradeableCashflow.address,
            providerOrSigner: accounts[0]
        })

        const initialOwnerFlowRate = await daix.getNetFlow({
            account: accounts[1].address,
            providerOrSigner: superSigner
        })

        console.log("initial owner flow rate: ", initialOwnerFlowRate)

        console.log(accounts[2].address)

        const daixTransferOperation = daix.transfer({
            receiver: accounts[2].address,
            amount: ethers.utils.parseEther("500")
        })

        await daixTransferOperation.exec(accounts[0])

        const account2Balance = await daix.balanceOf({
            account: accounts[2].address,
            providerOrSigner: superSigner
        })
        console.log("account 2 balance ", account2Balance)

        const createFlowOperation2 = daix.createFlow({
            receiver: TradeableCashflow.address,
            flowRate: "100000000"
        })

        const createFlowOperation2Txn = await createFlowOperation2.exec(
            accounts[2]
        )

        await createFlowOperation2Txn.wait()

        const appFlowRate = await daix.getNetFlow({
            account: TradeableCashflow.address,
            providerOrSigner: superSigner
        })

        const appFinalBalance = await daix.balanceOf({
            account: TradeableCashflow.address,
            providerOrSigner: superSigner
        })

        const updatedOwnerFlowRate2 = await daix.getNetFlow({
            account: accounts[1].address,
            providerOrSigner: superSigner
        })

        assert.equal(
            updatedOwnerFlowRate2,
            "300000000",
            "owner not receiving correct updated flowRate"
        )

        assert.equal(appFlowRate, 0, "App flowRate not zero")

        assert.equal(
            appInitialBalance.toString(),
            appFinalBalance.toString(),
            "balances aren't equal"
        )
    })

    //need deletion case
})

describe("Changing owner", async function () {
    it("Case #5 - When the owner changes, the flow changes", async () => {
        const initialOwnerFlowRate = await daix.getNetFlow({
            superToken: daix.address,
            account: accounts[1].address,
            providerOrSigner: superSigner
        })

        console.log("initial owner ", await TradeableCashflow.ownerOf(1))
        console.log("initial owner flowRate flowRate: ", initialOwnerFlowRate)

        const newOwnerFlowRate = await daix.getNetFlow({
            account: accounts[3].address,
            providerOrSigner: superSigner
        })

        console.log("new owner flowRate: ", newOwnerFlowRate)
        assert.equal(0, newOwnerFlowRate, "new owner shouldn't have flow yet")

        await TradeableCashflow.connect(accounts[1]).transferFrom(
            accounts[1].address,
            accounts[3].address,
            1
        )

        console.log("new owner, ", await TradeableCashflow.ownerOf(1))

        const initialOwnerUpdatedFlowRate = await daix.getNetFlow({
            account: accounts[1].address,
            providerOrSigner: superSigner
        })

        console.log(
            "initial owner updated flow rate",
            initialOwnerUpdatedFlowRate
        )

        assert.equal(
            initialOwnerUpdatedFlowRate,
            0,
            "old owner should no longer be receiving flows"
        )

        const newOwnerUpdatedFlowRate = await daix.getNetFlow({
            account: accounts[3].address,
            providerOrSigner: superSigner
        })

        console.log("new owner updated flowrate", newOwnerUpdatedFlowRate)

        assert.equal(
            newOwnerUpdatedFlowRate,
            initialOwnerFlowRate,
            "new receiver should be getting all of flow into app"
        )
    })
})
