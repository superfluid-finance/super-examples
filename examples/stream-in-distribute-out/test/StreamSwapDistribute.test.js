/* eslint-disable no-undef */
const { ethers } = require("hardhat")
const { assert } = require("chai")
const { Framework } = require("@superfluid-finance/sdk-core")
const { deployFramework, deployWrapperSuperToken } = require("./util/deploy-sf")

const minterRole =
    "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6"
const ten = ethers.utils.parseEther("10").toString()
const flowRate = ethers.utils.parseEther("0.000001").toString()
const updatedFlowRate = ethers.utils.parseEther("0.000002").toString()
const indexId = "0"
const overrides = { gasLimit: 3000000 } // Using this to manually limit gas to avoid giga-errors.

// Deploying signer
let admin,
    // Alice signer
    alice,
    // Bob signer
    bob,
    // Superfluid Framework Deployer Framework Object
    contractsFramework,
    // Superfluid sdk-core framework instance
    sf,
    // Underlying ERC20 of `inToken`
    inUnderlyingToken,
    // Underlying ERC20 of `outToken`
    outUnderlyingToken,
    // Super token to stream in
    inToken,
    // Super token to distribute out
    outToken,
    // Stream swap distribute super app
    streamSwapDistributeApp,
    // Uniswap router mock
    routerMock

before(async function () {
    ;[admin, alice, bob] = await ethers.getSigners()

    contractsFramework = await deployFramework(admin)
    console.log(contractsFramework)

    sf = await Framework.create({
        provider: admin.provider,
        resolverAddress: contractsFramework.resolver,
        dataMode: "WEB3_ONLY",
        protocolReleaseVersion: "test",
        networkName: "custom"
    })
})

beforeEach(async function () {
    // deploy tokens
    const inTokenDeployment = await deployWrapperSuperToken(
        admin,
        contractsFramework.superTokenFactory,
        "In Token",
        "ITn"
    )

    const outTokenDeployment = await deployWrapperSuperToken(
        admin,
        contractsFramework.superTokenFactory,
        "Out Token",
        "OTn"
    )

    // destructure token deployments
    inToken = inTokenDeployment.superToken
    inUnderlyingToken = inTokenDeployment.underlyingToken

    outToken = outTokenDeployment.superToken
    outUnderlyingToken = outTokenDeployment.underlyingToken

    // mint to alice and bob
    await inUnderlyingToken.mint(alice.address, ten)
    await inUnderlyingToken.connect(alice).approve(inToken.address, ten)
    await inToken.connect(alice).upgrade(ten)

    await inUnderlyingToken.mint(bob.address, ten)
    await inUnderlyingToken.connect(bob).approve(inToken.address, ten)
    await inToken.connect(bob).upgrade(ten)

    // deploy uniswap router mock
    const routerFactory = await ethers.getContractFactory(
        "UniswapRouterMock",
        admin
    )

    routerMock = await routerFactory.deploy()

    // grant mint permission to uniswap router mock
    inUnderlyingToken.grantRole(minterRole, routerMock.address)
    outUnderlyingToken.grantRole(minterRole, routerMock.address)

    // deploy super app
    const appFactory = await ethers.getContractFactory(
        "StreamSwapDistribute",
        admin
    )

    streamSwapDistributeApp = await appFactory.deploy(
        sf.settings.config.hostAddress,
        sf.settings.config.cfaV1Address,
        sf.settings.config.idaV1Address,
        inToken.address,
        outToken.address,
        routerMock.address
    )
})

describe("Streaming Operations", async function () {
    it("Can create flow to super app", async function () {
        await sf.cfaV1
            .createFlow({
                superToken: inToken.address,
                flowRate,
                receiver: streamSwapDistributeApp.address,
                overrides
            })
            .exec(alice)

        assert.equal(
            (
                await sf.cfaV1.getFlow({
                    superToken: inToken.address,
                    sender: alice.address,
                    receiver: streamSwapDistributeApp.address,
                    providerOrSigner: admin
                })
            ).flowRate,
            flowRate
        )

        assert.equal(
            (
                await sf.idaV1.getSubscription({
                    indexId,
                    superToken: outToken.address,
                    publisher: streamSwapDistributeApp.address,
                    subscriber: alice.address,
                    providerOrSigner: admin.provider
                })
            ).units,
            flowRate
        )
    })

    it("Can update flow to super app", async function () {
        await sf.cfaV1
            .createFlow({
                superToken: inToken.address,
                flowRate,
                receiver: streamSwapDistributeApp.address,
                overrides
            })
            .exec(alice)

        await sf.cfaV1
            .updateFlow({
                superToken: inToken.address,
                flowRate: updatedFlowRate,
                receiver: streamSwapDistributeApp.address,
                overrides
            })
            .exec(alice)

        assert.equal(
            (
                await sf.cfaV1.getFlow({
                    superToken: inToken.address,
                    sender: alice.address,
                    receiver: streamSwapDistributeApp.address,
                    providerOrSigner: admin
                })
            ).flowRate,
            updatedFlowRate
        )

        assert.equal(
            (
                await sf.idaV1.getSubscription({
                    indexId,
                    superToken: outToken.address,
                    publisher: streamSwapDistributeApp.address,
                    subscriber: alice.address,
                    providerOrSigner: admin.provider
                })
            ).units,
            updatedFlowRate
        )
    })

    it("Can delete flow to super app", async function () {
        await sf.cfaV1
            .createFlow({
                superToken: inToken.address,
                flowRate,
                receiver: streamSwapDistributeApp.address,
                overrides
            })
            .exec(alice)

        await sf.cfaV1
            .deleteFlow({
                superToken: inToken.address,
                sender: alice.address,
                receiver: streamSwapDistributeApp.address,
                overrides
            })
            .exec(alice)

        assert.equal(
            (
                await sf.cfaV1.getFlow({
                    superToken: inToken.address,
                    sender: alice.address,
                    receiver: streamSwapDistributeApp.address,
                    providerOrSigner: admin
                })
            ).flowRate,
            "0"
        )

        assert.equal(
            (
                await sf.idaV1.getSubscription({
                    indexId,
                    superToken: outToken.address,
                    publisher: streamSwapDistributeApp.address,
                    subscriber: alice.address,
                    providerOrSigner: admin.provider
                })
            ).units,
            "0"
        )
    })
})

describe("IDA Operations", async function () {
    it("Can approve subscription to super app", async function () {
        await sf.cfaV1
            .createFlow({
                superToken: inToken.address,
                flowRate,
                receiver: streamSwapDistributeApp.address,
                overrides
            })
            .exec(alice)

        await sf.idaV1
            .approveSubscription({
                indexId,
                superToken: outToken.address,
                publisher: streamSwapDistributeApp.address,
                overrides
            })
            .exec(alice)
    })
})

describe("Action operations", async () => {
    // this also asserts the `createFlow` = require(the first streamer won't throw)
    it("Can execute action with zero units", async function () {
        await streamSwapDistributeApp.connect(alice).executeAction()
        assert(true)
    })

    it("Can execute action after flow created", async function () {
        await sf.cfaV1
            .createFlow({
                superToken: inToken.address,
                flowRate,
                receiver: streamSwapDistributeApp.address,
                overrides
            })
            .exec(alice)

        await sf.idaV1
            .approveSubscription({
                indexId,
                superToken: outToken.address,
                publisher: streamSwapDistributeApp.address,
                overrides
            })
            .exec(alice)

        await streamSwapDistributeApp.connect(alice).executeAction()

        assert.notEqual(
            (await outToken.balanceOf(alice.address)).toString(),
            "0"
        )
    })
})
