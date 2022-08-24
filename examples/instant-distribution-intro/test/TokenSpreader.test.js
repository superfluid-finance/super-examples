const { expect } = require("chai")
const { Framework } = require("@superfluid-finance/sdk-core")
const { ethers } = require("hardhat")
const { deployFramework, deployWrapperSuperToken } = require("./util/deploy-sf")

let contractsFramework
let sf
let spreader
let dai
let daix

// Test Accounts
let admin
let alice
let bob

// Constants
const expecationDiffLimit = 10 // sometimes the IDA distributes a little less wei than expected. Accounting for potential discrepency with 10 wei margin

const thousandEther = ethers.utils.parseEther("10000")

before(async function () {
    // get hardhat accounts
    ;[admin, alice, bob] = await ethers.getSigners()

    // GETTING SUPERFLUID FRAMEWORK SET UP

    // deploy the framework locally
    contractsFramework = await deployFramework(admin)

    // initialize framework
    sf = await Framework.create({
        chainId: 31337,
        provider: admin.provider,
        resolverAddress: contractsFramework.resolver, // (empty)
        protocolReleaseVersion: "test"
    })

    // DEPLOYING DAI and DAI wrapper super token (which will be our `spreaderToken`)
    const tokenDeployment = await deployWrapperSuperToken(
        admin,
        contractsFramework.superTokenFactory,
        "fDAI",
        "fDAI"
    )

    dai = tokenDeployment.underlyingToken
    daix = tokenDeployment.superToken

    // minting test DAI
    await dai.mint(admin.address, thousandEther)
    await dai.mint(alice.address, thousandEther)
    await dai.mint(bob.address, thousandEther)

    // approving DAIx to spend DAI (Super Token object is not an ethers contract object and has different operation syntax)
    await dai.approve(daix.address, ethers.constants.MaxInt256)
    await dai.connect(alice).approve(daix.address, ethers.constants.MaxInt256)
    await dai.connect(bob).approve(daix.address, ethers.constants.MaxInt256)

    // Upgrading all DAI to DAIx
    await daix.upgrade(thousandEther)
    await daix.connect(alice).upgrade(thousandEther)
    await daix.connect(bob).upgrade(thousandEther)

    // INITIALIZING SPREADER CONTRACT

    const spreaderContractFactory = await ethers.getContractFactory(
        "TokenSpreader",
        admin
    )

    spreader = await spreaderContractFactory.deploy(
        sf.settings.config.hostAddress,
        daix.address // Setting DAIx as spreader token
    )

    // SUBSCRIBING TO SPREADER CONTRACT'S IDA INDEX

    // subscribe to distribution (doesn't matter if this happens before or after distribution execution)
    const approveSubscriptionOperation = await sf.idaV1.approveSubscription({
        indexId: "0",
        superToken: daix.address,
        publisher: spreader.address
    })
    await approveSubscriptionOperation.exec(alice)
    await approveSubscriptionOperation.exec(bob)
})

describe("TokenSpreader Test Sequence", async () => {
    it("Distribution with [ no units outstanding ] and [ no spreaderTokens held ]", async function () {
        // distribution SHOULD REVERT since no units are outstanding
        await expect(spreader.connect(alice).distribute()).to.be.reverted
    })

    it("Distribution with [ 1 unit issued ] but [ 0 spreaderTokens held ] - gainShare", async function () {
        // ACTIONS

        // Alice claims distribution unit
        await spreader.connect(alice).gainShare(alice.address)

        // EXPECTATIONS

        // expect alice to have 1 distribution unit
        let aliceSubscription = await sf.idaV1.getSubscription({
            superToken: daix.address,
            publisher: spreader.address,
            indexId: "0", // recall this was `INDEX_ID` in TokenSpreader.sol
            subscriber: alice.address,
            providerOrSigner: alice
        })

        await expect(aliceSubscription.units).to.equal("1")

        // distribution SHOULD NOT REVERT if there are outstanding units issued
        await expect(spreader.connect(alice).distribute()).to.be.not.reverted
    })

    it("Distribution with [ 2 units issued to different accounts ] but [ 0 spreaderTokens ] - gainShare", async function () {
        // ACTIONS

        // Bob claims distribution unit
        await spreader.connect(bob).gainShare(bob.address)

        // EXPECTATIONS

        // expect alice to have 1 distribution unit
        let aliceSubscription = await sf.idaV1.getSubscription({
            superToken: daix.address,
            publisher: spreader.address,
            indexId: "0", // recall this was `INDEX_ID` in TokenSpreader.sol
            subscriber: alice.address,
            providerOrSigner: alice
        })

        await expect(aliceSubscription.units).to.equal("1")

        // expect bob to have 1 distribution unit
        let bobSubscription = await sf.idaV1.getSubscription({
            superToken: daix.address,
            publisher: spreader.address,
            indexId: "0", // recall this was `INDEX_ID` in TokenSpreader.sol
            subscriber: bob.address,
            providerOrSigner: bob
        })

        await expect(bobSubscription.units).to.equal("1")

        // distribution SHOULD NOT REVERT if there are outstanding units issued
        await expect(spreader.connect(alice).distribute()).to.be.not.reverted
    })

    it("Distribution with [ 2 units issued to different accounts ] and [ 100 spreaderTokens ] - gainShare", async function () {
        let distributionAmount = ethers.utils.parseEther("100")

        // ACTIONS

        // Admin gives spreader 100 DAIx
        await daix.transfer(spreader.address, distributionAmount)

        // (snapshot balances)
        let aliceInitialBlance = await daix.balanceOf(alice.address)
        let bobInitialBlance = await daix.balanceOf(bob.address)

        // Distribution executed
        await expect(spreader.connect(admin).distribute()).to.be.not.reverted

        // EXPECTATIONS

        // expect alice to receive 1/2 of distribution
        await expect(await daix.balanceOf(alice.address)).to.closeTo(
            ethers.BigNumber.from(aliceInitialBlance).add(
                distributionAmount.div("2")
            ), // expect original balance + distribution amount / 2
            expecationDiffLimit
        )

        // expect bob to receive 1/2 of distribution
        await expect(await daix.balanceOf(bob.address)).to.closeTo(
            ethers.BigNumber.from(bobInitialBlance).add(
                distributionAmount.div("2")
            ), // expect original balance + distribution amount / 2
            expecationDiffLimit
        )

        // expect balance of spreader contract to be zeroed out
        await expect(await daix.balanceOf(spreader.address)).to.closeTo(
            ethers.BigNumber.from("0"),
            expecationDiffLimit
        )
    })

    it("Distribution with [ 3 units issued to different accounts ] and [ 100 spreaderTokens ] - gainShare", async function () {
        let distributionAmount = ethers.utils.parseEther("100")

        // ACTIONS

        // Bob claims another distribution unit
        await spreader.connect(bob).gainShare(bob.address)

        // Admin gives spreader 100 DAIx
        await daix.transfer(spreader.address, distributionAmount)

        // (snapshot balances)
        let aliceInitialBlance = await daix.balanceOf(alice.address)
        let bobInitialBlance = await daix.balanceOf(bob.address)

        // Distribution executed
        await expect(spreader.connect(admin).distribute()).to.be.not.reverted

        // EXPECTATIONS

        // expect bob to have 2 distribution units
        let bobSubscription = await sf.idaV1.getSubscription({
            superToken: daix.address,
            publisher: spreader.address,
            indexId: "0", // recall this was `INDEX_ID` in TokenSpreader.sol
            subscriber: bob.address,
            providerOrSigner: bob
        })

        await expect(bobSubscription.units).to.equal("2")

        // expect alice to receive 1/3 of distribution
        await expect(await daix.balanceOf(alice.address)).to.closeTo(
            ethers.BigNumber.from(aliceInitialBlance).add(
                distributionAmount.div("3")
            ), // expect original balance + distribution amount * 1/2
            expecationDiffLimit
        )

        // expect bob to receive 2/3 of distribution
        await expect(await daix.balanceOf(bob.address)).to.closeTo(
            ethers.BigNumber.from(bobInitialBlance).add(
                distributionAmount.div("3").mul("2")
            ), // expect original balance + distribution amount * 2/3
            expecationDiffLimit
        )

        // expect balance of spreader contract to be zeroed out
        await expect(await daix.balanceOf(spreader.address)).to.closeTo(
            ethers.BigNumber.from("0"),
            expecationDiffLimit
        )
    })

    it("Distribution with [ 2 units issued to single account ] and [ 100 spreaderTokens ] - deleteShares", async function () {
        let distributionAmount = ethers.utils.parseEther("100")

        // ACTIONS

        // Alice deletes here entire subscription
        await spreader.connect(alice).deleteShares(alice.address)

        // Admin gives spreader 100 DAIx
        await daix.transfer(spreader.address, distributionAmount)

        // (snapshot balances)
        let aliceInitialBlance = await daix.balanceOf(alice.address)
        let bobInitialBlance = await daix.balanceOf(bob.address)

        // Distribution executed
        await expect(spreader.connect(admin).distribute()).to.be.not.reverted

        // EXPECTATIONS

        // expect alice to have 0 distribution units
        let aliceSubscription = await sf.idaV1.getSubscription({
            superToken: daix.address,
            publisher: spreader.address,
            indexId: "0", // recall this was `INDEX_ID` in TokenSpreader.sol
            subscriber: alice.address,
            providerOrSigner: alice
        })

        await expect(aliceSubscription.units).to.equal("0")

        // expect alice to receive none of distribution
        await expect(await daix.balanceOf(alice.address)).to.closeTo(
            ethers.BigNumber.from(aliceInitialBlance), // expect original balance
            expecationDiffLimit
        )

        // expect bob to receive all of distribution
        await expect(await daix.balanceOf(bob.address)).to.closeTo(
            ethers.BigNumber.from(bobInitialBlance).add(distributionAmount), // expect original balance + distribution amount
            expecationDiffLimit
        )

        // expect balance of spreader contract to be zeroed out
        await expect(await daix.balanceOf(spreader.address)).to.closeTo(
            ethers.BigNumber.from("0"),
            expecationDiffLimit
        )
    })

    it("Distribution with [ 1 unit issued to single account ] and [ 100 spreaderTokens ] - loseShare", async function () {
        let distributionAmount = ethers.utils.parseEther("100")

        // ACTIONS

        // Bob deletes one of his two units
        await spreader.connect(bob).loseShare(bob.address)

        // Admin gives spreader 100 DAIx
        await daix.transfer(spreader.address, distributionAmount)

        // (snapshot balances)
        let aliceInitialBlance = await daix.balanceOf(alice.address)
        let bobInitialBlance = await daix.balanceOf(bob.address)

        // Distribution executed
        await expect(spreader.connect(admin).distribute()).to.be.not.reverted

        // EXPECTATIONS

        // expect bob to have 1 distribution unit
        let bobSubscription = await sf.idaV1.getSubscription({
            superToken: daix.address,
            publisher: spreader.address,
            indexId: "0", // recall this was `INDEX_ID` in TokenSpreader.sol
            subscriber: bob.address,
            providerOrSigner: bob
        })

        await expect(bobSubscription.units).to.equal("1")

        // expect alice to receive none of distribution
        await expect(await daix.balanceOf(alice.address)).to.closeTo(
            ethers.BigNumber.from(aliceInitialBlance), // expect original balance
            expecationDiffLimit
        )

        // expect bob to receive all of distribution
        await expect(await daix.balanceOf(bob.address)).to.closeTo(
            ethers.BigNumber.from(bobInitialBlance).add(distributionAmount), // expect original balance + distribution amount
            expecationDiffLimit
        )

        // expect balance of spreader contract to be zeroed out
        await expect(await daix.balanceOf(spreader.address)).to.closeTo(
            ethers.BigNumber.from("0"),
            expecationDiffLimit
        )
    })

    it("Distribution with [ no units outstanding ] and [ 100 spreaderTokens ] - loseShare", async function () {
        let distributionAmount = ethers.utils.parseEther("100")

        // ACTIONS

        // Bob deletes his last unit
        await spreader.connect(bob).loseShare(bob.address)

        // Admin gives spreader 100 DAIx
        await daix.transfer(spreader.address, distributionAmount)

        // (snapshot balances)
        let aliceInitialBlance = await daix.balanceOf(alice.address)
        let bobInitialBlance = await daix.balanceOf(bob.address)

        // distribution SHOULD REVERT since no units are outstanding
        await expect(spreader.connect(admin).distribute()).to.be.reverted

        // EXPECTATIONS

        // expect bob to have no distribution units
        let bobSubscription = await sf.idaV1.getSubscription({
            superToken: daix.address,
            publisher: spreader.address,
            indexId: "0", // recall this was `INDEX_ID` in TokenSpreader.sol
            subscriber: bob.address,
            providerOrSigner: bob
        })

        await expect(bobSubscription.units).to.equal("0")

        // expect alice to receive none of distribution
        await expect(await daix.balanceOf(alice.address)).to.closeTo(
            ethers.BigNumber.from(aliceInitialBlance), // expect original balance
            expecationDiffLimit
        )

        // expect bob to receive none of distribution
        await expect(await daix.balanceOf(bob.address)).to.closeTo(
            ethers.BigNumber.from(bobInitialBlance), // expect original balance
            expecationDiffLimit
        )

        // expect balance of spreader contract to remain same
        await expect(await daix.balanceOf(spreader.address)).to.closeTo(
            distributionAmount,
            expecationDiffLimit
        )
    })
})
