const hre = require("hardhat");
const ethers = hre.ethers;
const { Framework } = require("@superfluid-finance/sdk-core");

async function main() {

  const { deployer } = await getNamedAccounts()
  console.log("Deploying With:", deployer)

  //// Applying best practices and using Superfluid Framework to get deployment info

  // Setting up network object - this is set as the goerli url, but can be changed to reflect your RPC URL and network of choice
  const url = `${process.env.GOERLI_URL}`;
  const customHttpProvider = new ethers.providers.JsonRpcProvider(url);
  const network = await customHttpProvider.getNetwork();

  // Setting up the out Framework object with Goerli (knows it's Goerli when we pass in network.chainId)
  const sf = await Framework.create({
    chainId: network.chainId,
    provider: customHttpProvider
  });

  // Getting the Goerli fDAIx Super Token object from the Framework object
  // This is fDAIx on goerli - you can change this token to suit your network and desired token address
  const daix = await sf.loadSuperToken("fDAIx");

  //// Actually deploying

  // We get the contract to deploy to Gorli Testnet
  const TradeableCashflow = await ethers.getContractFactory("TradeableCashflow");
  const tradeablecashflow = await TradeableCashflow.deploy(
    deployer,
    "DAIx Bowl",
    "DAIxBOWL",
    sf.settings.config.hostAddress,
    daix.address                
  );

  await tradeablecashflow.deployed();

  console.log("DAIx Bowl deployed to:", tradeablecashflow.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

// Verify: npx hardhat verify --network goerli --constructor-args arguments-tc.js [contractaddress]