const { assert } = require("chai")
const { Framework } = require("@superfluid-finance/sdk-core")
const { ethers } = require("hardhat")
const { deployTestFramework } = require("@superfluid-finance/ethereum-contracts/dev-scripts/deploy-test-framework");
const TestToken = require("@superfluid-finance/ethereum-contracts/build/contracts/TestToken.json")
const hostABI = require("@superfluid-finance/ethereum-contracts/build/contracts/Superfluid.json");

let provider;

let sfDeployer
let contractsFramework

let alice
let bob
let carol
let mainReceiver
let sideReceiver

let sf
let dai
let daix
let flowSplitter
let hostContract

const thousandEther = ethers.utils.parseEther("10000")

before(async function () {

    // Get accounts from hardhat
    [alice, bob, carol, mainReceiver, sideReceiver] = await ethers.getSigners()
    provider = alice.provider;
    sfDeployer = await deployTestFramework()
    console.log("Alice:", alice.address);
    console.log("Bob:", bob.address);

    ////////// Setting up Superfluid Framework & Super Tokens //////////

    // deploy the framework locally
    contractsFramework = await sfDeployer.frameworkDeployer.getFramework()

    // Initialize the superfluid framework...put custom and web3 only bc we are using hardhat locally
    sf = await Framework.create({
        chainId: 31337,                               //note: this is hardhat's local chainId
        provider,
        resolverAddress: contractsFramework.resolver, // this is how you get the resolver address
        protocolReleaseVersion: "test"
    })

    hostContract = new ethers.Contract(sf.settings.config.hostAddress, hostABI.abi, alice);
    console.log("Host:", hostContract.address);

    // DEPLOYING DAI and DAI wrapper super token
    tokenDeployment = await sfDeployer.frameworkDeployer.deployWrapperSuperToken(
        "Fake DAI Token",
        "fDAI",
        18,
        ethers.utils.parseEther("100000000").toString()
    )

    // Use the framework to get the super toen
    daix = await sf.loadSuperToken("fDAIx");
    dai = new ethers.Contract(
        daix.underlyingToken.address,
        TestToken.abi,
        alice
    )

    ////////// Loading Accounts with Tokens //////////

    // minting test DAI
    await dai.connect(alice).mint(alice.address, thousandEther)
    await dai.connect(bob).mint(bob.address, thousandEther)
    await dai.connect(carol).mint(carol.address, thousandEther)
    await dai.connect(mainReceiver).mint(mainReceiver.address, thousandEther)
    await dai.connect(sideReceiver).mint(sideReceiver.address, thousandEther)
    
    // approving DAIx to spend DAI (Super Token object is not an etherscontract object and has different operation syntax)
    await dai.connect(alice).approve(daix.address, ethers.constants.MaxInt256)
    await dai.connect(bob).approve(daix.address, ethers.constants.MaxInt256)
    await dai.connect(carol).approve(daix.address, ethers.constants.MaxInt256)
    await dai.connect(mainReceiver).approve(daix.address, ethers.constants.MaxInt256)
    await dai.connect(sideReceiver).approve(daix.address, ethers.constants.MaxInt256)

    // Upgrading all DAI to DAIx
    const upgradeOp = daix.upgrade({ amount: thousandEther })
    
    await upgradeOp.exec(alice)
    await upgradeOp.exec(bob)
    await upgradeOp.exec(carol)
    await upgradeOp.exec(mainReceiver)
    await upgradeOp.exec(sideReceiver)

    const daixBal = await daix.balanceOf({
        account: alice.address,
        providerOrSigner: alice
    })

    console.log("DAIx balance for each account:", daixBal)

    ////////// Deploying FlowSplitter //////////

    let FlowSplitter = await ethers.getContractFactory("FlowSplitter", alice)

    flowSplitter = await FlowSplitter.deploy(
      mainReceiver.address,
      sideReceiver.address,
      300,                                    // 30% split off to side receiver
      daix.address,
      sf.settings.config.hostAddress
    );

    console.log("FlowSplitter:", flowSplitter.address);

    // Transferring FlowSplitter some DAIx to help with its solvency
    let transferOp = daix.transfer({
      receiver: flowSplitter.address,
      amount: (100000000*60*60*4).toString()
    })
    await (await transferOp.exec(carol)).wait();

});


describe("sending flows", async function () {
    it("Case #1 - Alice sends a flow", async () => {

        // Expected end state:
        // Inflow = 100000000
        // Outflow = 7000000 (to mainReceiver) + 3000000 (to sideReceiver)

        const createFlowOperation = daix.createFlow({
            receiver: flowSplitter.address,
            flowRate: "100000000"
        })

        await (await createFlowOperation.exec(alice)).wait();

        const appFlowRate = await daix.getNetFlow({
            account: flowSplitter.address,
            providerOrSigner: alice
        })
        assert.equal(appFlowRate, 0, "flowSplitter net flow rate not zero")

        const mainReceiverFlow = await daix.getFlow({
          sender: flowSplitter.address,
          receiver: mainReceiver.address,
          providerOrSigner: alice
        });
        assert.equal(mainReceiverFlow.flowRate, "70000000", "mainReceiver flow incorrect")

        const sideReceiverFlow = await daix.getFlow({
          sender: flowSplitter.address,
          receiver: sideReceiver.address,
          providerOrSigner: alice
        });
        assert.equal(sideReceiverFlow.flowRate, "30000000", "sideReceiver flow incorrect")

    })

    it("Case #2 - Bob sends a flow", async () => {

      // Expected end state:
      // Inflow = 150000000
      // Outflow = 14000000 (to mainReceiver) + 6000000 (to sideReceiver)

      const createFlowOperation = daix.createFlow({
        receiver: flowSplitter.address,
        flowRate: "100000000"
      })

      await (await createFlowOperation.exec(bob)).wait();

      const appFlowRate = await daix.getNetFlow({
          account: flowSplitter.address,
          providerOrSigner: alice
      })
      assert.equal(appFlowRate, 0, "flowSplitter net flow rate not zero")

      const mainReceiverFlow = await daix.getFlow({
        sender: flowSplitter.address,
        receiver: mainReceiver.address,
        providerOrSigner: alice
      });
      assert.equal(mainReceiverFlow.flowRate, "140000000", "mainReceiver flow incorrect")

      const sideReceiverFlow = await daix.getFlow({
        sender: flowSplitter.address,
        receiver: sideReceiver.address,
        providerOrSigner: alice
      });
      assert.equal(sideReceiverFlow.flowRate, "60000000", "sideReceiver flow incorrect")

    })

    it("Case #3 - Alice updates her flow", async () => {

        // Expected end state:
        // Inflow = 150000000
        // Outflow = 10500000 (to mainReceiver) + 4500000 (to sideReceiver)

        const updateFlowOperation = daix.updateFlow({
            receiver: flowSplitter.address,
            flowRate: "50000000"
        })

        await (await updateFlowOperation.exec(alice)).wait();

        const appFlowRate = await daix.getNetFlow({
            account: flowSplitter.address,
            providerOrSigner: alice
        })
        assert.equal(appFlowRate, 0, "flowSplitter net flow rate not zero")

        const mainReceiverFlow = await daix.getFlow({
          sender: flowSplitter.address,
          receiver: mainReceiver.address,
          providerOrSigner: alice
        });
        assert.equal(mainReceiverFlow.flowRate, "105000000", "mainReceiver flow incorrect")

        const sideReceiverFlow = await daix.getFlow({
          sender: flowSplitter.address,
          receiver: sideReceiver.address,
          providerOrSigner: alice
        });
        assert.equal(sideReceiverFlow.flowRate, "45000000", "sideReceiver flow incorrect")

    })

    it("Case #4 - Split is updated from 70/30 to 60/40", async () => {

        // Expected end state:
        // Inflow = 150000000
        // Outflow = 9000000 (to mainReceiver) + 6000000 (to sideReceiver)

        await (await flowSplitter.updateSplit(400)).wait();

        const appFlowRate = await daix.getNetFlow({
            account: flowSplitter.address,
            providerOrSigner: alice
        })
        assert.equal(appFlowRate, 0, "flowSplitter net flow rate not zero")

        const mainReceiverFlow = await daix.getFlow({
          sender: flowSplitter.address,
          receiver: mainReceiver.address,
          providerOrSigner: alice
        });
        assert.equal(mainReceiverFlow.flowRate, "90000000", "mainReceiver flow incorrect")

        const sideReceiverFlow = await daix.getFlow({
          sender: flowSplitter.address,
          receiver: sideReceiver.address,
          providerOrSigner: alice
        });
        assert.equal(sideReceiverFlow.flowRate, "60000000", "sideReceiver flow incorrect")

    });

    it("Case #5 - Bob deletes his flow", async () => {

      // Expected end state:
      // Inflow = 50000000
      // Outflow = 30000000 (to mainReceiver) + 2000000 (to sideReceiver)

      const deleteFlowOperation = daix.deleteFlow({
          sender: bob.address,
          receiver: flowSplitter.address
      })

      await (await deleteFlowOperation.exec(bob)).wait();

      const appFlowRate = await daix.getNetFlow({
          account: flowSplitter.address,
          providerOrSigner: alice
      })
      assert.equal(appFlowRate, 0, "flowSplitter net flow rate not zero")

      const mainReceiverFlow = await daix.getFlow({
        sender: flowSplitter.address,
        receiver: mainReceiver.address,
        providerOrSigner: alice
      });
      assert.equal(mainReceiverFlow.flowRate, "30000000", "mainReceiver flow incorrect")

      const sideReceiverFlow = await daix.getFlow({
        sender: flowSplitter.address,
        receiver: sideReceiver.address,
        providerOrSigner: alice
      });
      assert.equal(sideReceiverFlow.flowRate, "20000000", "sideReceiver flow incorrect")

  })

  it("Case #6 - Alice deletes her flow", async () => {

      // Expected end state:
      // Inflow = 0
      // Outflow = 0 (to mainReceiver) + 0 (to sideReceiver)

      const deleteFlowOperation = daix.deleteFlow({
          sender: alice.address,
          receiver: flowSplitter.address
      })

      await (await deleteFlowOperation.exec(alice)).wait();

      const appFlowRate = await daix.getNetFlow({
          account: flowSplitter.address,
          providerOrSigner: alice
      })
      assert.equal(appFlowRate, 0, "flowSplitter net flow rate not zero")

      const mainReceiverFlow = await daix.getFlow({
        sender: flowSplitter.address,
        receiver: mainReceiver.address,
        providerOrSigner: alice
      });
      assert.equal(mainReceiverFlow.flowRate, "0", "mainReceiver flow incorrect")

      const sideReceiverFlow = await daix.getFlow({
        sender: flowSplitter.address,
        receiver: sideReceiver.address,
        providerOrSigner: alice
      });
      assert.equal(sideReceiverFlow.flowRate, "0", "sideReceiver flow incorrect")

  })

})