const { expect } = require("chai")
const { ethers } = require("hardhat")
const { time } = require("@nomicfoundation/hardhat-network-helpers");
const { Framework } = require("@superfluid-finance/sdk-core")
const { deployTestFramework } = require("@superfluid-finance/ethereum-contracts/dev-scripts/deploy-test-framework");
const TestToken = require("@superfluid-finance/ethereum-contracts/build/hardhat/contracts/utils/TestToken.sol/TestToken.json")

let sfDeployer
let contractsFramework
let sf
let flower
let dai
let daix

// Test Accounts
let owner
let alice
let bob

const thousandEther = ethers.utils.parseEther("10000")
const EXPECATION_DIFF_LIMIT = 50;    // Accounting for potential discrepency with 10 wei margin

before(async function () {

    // get hardhat accounts
    ;[owner, alice, bob] = await ethers.getSigners()

    sfDeployer = await deployTestFramework();

    // GETTING SUPERFLUID FRAMEWORK SET UP

    // deploy the framework locally
    contractsFramework = await sfDeployer.frameworkDeployer.getFramework()

    // initialize framework
    sf = await Framework.create({
        chainId: 31337,
        provider: owner.provider,
        resolverAddress: contractsFramework.resolver, // (empty)
        protocolReleaseVersion: "test"
    })

    // DEPLOYING DAI and DAI wrapper super token
    tokenDeployment = await sfDeployer.frameworkDeployer.deployWrapperSuperToken(
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
    await dai.mint(alice.address, thousandEther)
    await dai.mint(bob.address, thousandEther)

    // approving DAIx to spend DAI (Super Token object is not an ethers contract object and has different operation syntax)
    await dai.approve(daix.address, ethers.constants.MaxInt256)
    await dai
        .connect(alice)
        .approve(daix.address, ethers.constants.MaxInt256)
    await dai
        .connect(bob)
        .approve(daix.address, ethers.constants.MaxInt256)

    // Upgrading all DAI to DAIx
    const ownerUpgrade = daix.upgrade({ amount: thousandEther })
    const aliceUpgrade = daix.upgrade({ amount: thousandEther })
    const bobUpgrade = daix.upgrade({ amount: thousandEther })

    await ownerUpgrade.exec(owner)
    await aliceUpgrade.exec(alice)
    await bobUpgrade.exec(bob)

    let FlowerFactory = await ethers.getContractFactory("Flower", owner)

    console.log("Host", sf.settings.config.hostAddress);
    console.log("CFA ", sf.settings.config.cfaV1Address);

    flower = await FlowerFactory.deploy(
        [1000, 1000, 1000],
        [
            "ipfs://QmYUXy3JjoCjx1Fji71v9pPAWs3kAdrhBtUvVJw6m89g4A/plant1.json",
            "ipfs://QmYUXy3JjoCjx1Fji71v9pPAWs3kAdrhBtUvVJw6m89g4A/plant2.json",
            "ipfs://QmYUXy3JjoCjx1Fji71v9pPAWs3kAdrhBtUvVJw6m89g4A/plant3.json"
        ],
        daix.address,
        sf.settings.config.hostAddress
    )
    await flower.deployed()
})

describe("Flower Contract", function () {

    it("Creating a stream, token is minted", async function () {

        // Bob starts a stream to the Flower contract
        let flowOp = sf.cfaV1.createFlow({
            superToken: daix.address,
            sender: bob.address,
            receiver: flower.address,
            flowRate: "1"
        });
        await flowOp.exec(bob);

        // Verify that Bob has a Flower NFT
        expect(
            await flower.balanceOf(bob.address)
        ).to.eq(1);

        // Verify that it's recorded in `flowerOwned` mapping
        expect(
            await flower.flowerOwned(bob.address)
        ).to.eq(1);

        // Verify that metadata is [0]
        expect(
            await flower.tokenURI("1")
        ).to.eq("ipfs://QmYUXy3JjoCjx1Fji71v9pPAWs3kAdrhBtUvVJw6m89g4A/plant1.json");

    });

    it("Updating a stream", async function () {

        // update flow
        let flowOp = sf.cfaV1.updateFlow({
            superToken: daix.address,
            sender: bob.address,
            receiver: flower.address,
            flowRate: "2"
        });
        await flowOp.exec(bob);  
        let trackedTime = await time.latest();      

        // forward time 200 sec
        let timeIncrease = 200
        await time.increaseTo( trackedTime + timeIncrease );

        // expect correct amount streamedSoFar
        let amountStreamedToFlower = await flower.streamedSoFar(1) ;
        expect( 
            amountStreamedToFlower
        ).is.closeTo(
            timeIncrease * 2,
            EXPECATION_DIFF_LIMIT
        );

    });

    it("Deleting a stream", async function () {

        // get initial amount streamed
        let amountStreamedToFlower = await flower.streamedSoFar(1) ;

        // delete flow
        let flowOp = sf.cfaV1.deleteFlow({
            superToken: daix.address,
            sender: bob.address,
            receiver: flower.address
        });
        await flowOp.exec(bob);

        // expect correct amount streamedSoFar (it should be unchanged)
        expect( 
            amountStreamedToFlower
        ).is.closeTo(
            await flower.streamedSoFar(1),
            EXPECATION_DIFF_LIMIT
        );

    });

    it("Re-creating a stream", async function () {

        // Bob restarts a stream to the Flower contract
        let flowOp = sf.cfaV1.createFlow({
            superToken: daix.address,
            sender: bob.address,
            receiver: flower.address,
            flowRate: "1"
        });
        await flowOp.exec(bob);

        // Verify that Bob has one Flower NFT
        expect(
            await flower.balanceOf(bob.address)
        ).to.eq(1);

        // Verify that metadata is still [0]
        expect(
            await flower.tokenURI("1")
        ).to.eq("ipfs://QmYUXy3JjoCjx1Fji71v9pPAWs3kAdrhBtUvVJw6m89g4A/plant1.json");

    });

    it("Flower grows properly", async function () {

        let trackedTime = await time.latest();      

        // speed forward 700 seconds
        await time.increaseTo( trackedTime + 700 );
        trackedTime = await time.latest();

        // Verify that metadata is now [1]
        expect(
            await flower.tokenURI("1")
        ).to.eq("ipfs://QmYUXy3JjoCjx1Fji71v9pPAWs3kAdrhBtUvVJw6m89g4A/plant2.json");

        // speed forward another 1000 seconds
        await time.increaseTo( trackedTime + 1000 );
        trackedTime = await time.latest();

        // Verify that metadata is now [2]
        expect(
            await flower.tokenURI("1")
        ).to.eq("ipfs://QmYUXy3JjoCjx1Fji71v9pPAWs3kAdrhBtUvVJw6m89g4A/plant3.json");

        // speed forward another 10000 seconds
        await time.increaseTo( trackedTime + 10000 );

        // Verify that metadata is still [2]
        expect(
            await flower.tokenURI("1")
        ).to.eq("ipfs://QmYUXy3JjoCjx1Fji71v9pPAWs3kAdrhBtUvVJw6m89g4A/plant3.json");

    })

    it("Transfering the NFT", async function () {

        // transfer NFT to alice
        await flower.connect(bob).transferFrom(bob.address, alice.address, "1");
        let trackedTime = await time.latest();

        // expect NFT possession to be changed in `flowerOwned` mapping
        expect(
            await flower.flowerOwned(bob.address)
        ).to.eq(0);
        expect(
            await flower.flowerOwned(alice.address)
        ).to.eq(1);

        // expect Flower profile data to be updated: latestFlowMod, flowRate, streamedSoFarAtLatestMod
        let flowerProf = await flower.flowerProfiles("1");
        expect(
            flowerProf.latestFlowMod
        ).to.eq(
            trackedTime
        );
        expect(
            flowerProf.flowRate
        ).to.eq(
            0
        );
        expect(
            flowerProf.streamedSoFarAtLatestMod
        ).is.closeTo(
            12100,
            EXPECATION_DIFF_LIMIT
        );

        // expect flow from Bob to be cancelled
        expect(
            ( await sf.cfaV1.getFlow({
                superToken: daix.address,
                sender: bob.address,
                receiver: flower.address,
                providerOrSigner: bob
            }) ).flowRate
        ).to.eq(
            '0'
        );

    });

    it("Resuming a stream with the received NFT", async function () {

        // Bob restarts a stream to the Flower contract
        let flowOp = sf.cfaV1.createFlow({
            superToken: daix.address,
            sender: alice.address,
            receiver: flower.address,
            flowRate: "1"
        });
        await flowOp.exec(alice);

        // Verify that metadata is still [2]
        expect(
            await flower.tokenURI("1")
        ).to.eq("ipfs://QmYUXy3JjoCjx1Fji71v9pPAWs3kAdrhBtUvVJw6m89g4A/plant3.json");

    });

    it("Account that previously had an NFT can mint another", async function () {

        // Bob restarts a stream to the Flower contract
        let flowOp = sf.cfaV1.createFlow({
            superToken: daix.address,
            sender: bob.address,
            receiver: flower.address,
            flowRate: "1"
        });
        await flowOp.exec(bob);

        // Verify that Bob has one Flower NFT
        expect(
            await flower.balanceOf(bob.address)
        ).to.eq(1);

        // Verify that metadata is [0]
        expect(
            await flower.tokenURI("2")
        ).to.eq("ipfs://QmYUXy3JjoCjx1Fji71v9pPAWs3kAdrhBtUvVJw6m89g4A/plant1.json");

    });

    it("Account can't have multiple NFTs", async function () {

        await expect(
            flower.connect(bob).transferFrom(bob.address, alice.address, "2")
        ).to.be.revertedWithCustomError(
            flower,
            "InvalidTransfer"
        );

    });

    xit("Happy path", async function () {

        // Bob starts a stream to the Flower contract
        let flowOp = sf.cfaV1.createFlow({
            superToken: daix.address,
            sender: bob.address,
            receiver: flower.address,
            flowRate: "1"
        });
        await flowOp.exec(bob);

        // Verify that Bob has a Flower NFT
        expect(
            await flower.balanceOf(bob.address)
        ).to.eq(1);

        // Verify that metadata is [0], Print its metadata
        expect(
            await flower.tokenURI("1")
        ).to.eq("ipfs://QmYUXy3JjoCjx1Fji71v9pPAWs3kAdrhBtUvVJw6m89g4A/plant1.json");
        console.log(await flower.tokenURI("1"));

        // Fastforward 1000 sec
        await network.provider.send("evm_increaseTime", [1000]);
        await network.provider.send("evm_mine");

        // Verify that metadata is [1], Print its metadata
        expect(
            await flower.tokenURI("1")
        ).to.eq("ipfs://QmYUXy3JjoCjx1Fji71v9pPAWs3kAdrhBtUvVJw6m89g4A/plant2.json");
        console.log(await flower.tokenURI("1"));

        // Fastforward 1000 sec
        await network.provider.send("evm_increaseTime", [1000]);
        await network.provider.send("evm_mine");

        // Verify that metadata is [2], Print its metadata
        expect(
            await flower.tokenURI("1")
        ).to.eq("ipfs://QmYUXy3JjoCjx1Fji71v9pPAWs3kAdrhBtUvVJw6m89g4A/plant3.json");
        console.log(await flower.tokenURI("1"));

        // Fastforward 1000 sec
        await network.provider.send("evm_increaseTime", [1000000]);
        await network.provider.send("evm_mine");

        // Verify that metadata is [2], Print its metadata
        expect(
            await flower.tokenURI("1")
        ).to.eq("ipfs://QmYUXy3JjoCjx1Fji71v9pPAWs3kAdrhBtUvVJw6m89g4A/plant3.json");
        console.log(await flower.tokenURI("1"));


    });

});