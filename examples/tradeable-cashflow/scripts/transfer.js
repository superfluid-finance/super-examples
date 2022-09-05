const hre = require("hardhat");
const ethers = hre.ethers;
const tcJSON = require("../artifacts/contracts/TradeableCashflow.sol/TradeableCashflow.json")
const tcABI = tcJSON.abi;

async function main() {


    let deployer;
    let alice;
    let bob;
    [deployer, alice, bob] = await ethers.getSigners();

      // Setting up network object - this is set as the goerli url, but can be changed to reflect your RPC URL and network of choice
    const url = `${process.env.GOERLI_URL}`;
    const customHttpProvider = new ethers.providers.JsonRpcProvider(url);
    const network = await customHttpProvider.getNetwork();

    // const tradeablecashflow = await ethers.getContractAt(tcABI, "0x78655F79Bd98A0b3998CdCEd40a00ce8ABee3849", network);
    const tradeablecashflow = new ethers.Contract("0x4028936273734F3A2144f65C477a32fF2014724F", tcABI, customHttpProvider)

    const transferingFrom = alice; // set sender
    console.log("Transfering From:", transferingFrom.address);

    // const transferingTo = alice; // set receiver
    console.log("Transfering To:", "0x6c5370Ae449A096f397c5AC6A80f815377503d7D");

    const transferTx = await tradeablecashflow.connect(transferingFrom).transferFrom(
        transferingFrom.address,
        "0x6c5370Ae449A096f397c5AC6A80f815377503d7D",
        1
    );
    await transferTx.wait();

    console.log("Transfer Successful!:", transferTx.hash)


}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });