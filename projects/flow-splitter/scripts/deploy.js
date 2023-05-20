// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {

  const mainReceiver = "" // Input mainReceiver address here
  const sideReceiver = "" // Input sideReceiver address here

  const sideReceiverPortion = 0 // Select a sideReceiver portion with a number between 1 and 1000 here 
                                // 300 would represent routing 30% of incoming flow to the sideReceiver

  // For help picking below addresses, head to: https://docs.superfluid.finance/superfluid/developers/networks
  const acceptedSuperToken = "" // address of Super Token to be accepted to be streamed to FlowSplitter
  const host = "" // address of Superfluid Host contract for network of deployment

  const FlowSplitter = await hre.ethers.getContractFactory("FlowSplitter");
  const flowSplitter = await FlowSplitter.deploy(
    mainReceiver,
    sideReceiver,
    sideReceiverPortion,
    acceptedSuperToken,
    host
  );

  await flowSplitter.deployed();

  console.log("Flow Splitter:", flowSplitter.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
