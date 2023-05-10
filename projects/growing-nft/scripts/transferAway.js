// Get rid of Flower NFT in possession

const hre = require("hardhat");
const { Framework } = require("@superfluid-finance/sdk-core");
const deployedContracts = require("./utils/deployedContracts");
const { ethers } = require("hardhat");
const flowerABI = require("../artifacts/contracts/Flower.sol/Flower.json");

const banishAddress = "0x455E5AA18469bC6ccEF49594645666C587A3a71B";

async function main() {

    const signer = await hre.ethers.getSigner(); 

    let flower = await hre.ethers.getContractAt( flowerABI.abi, deployedContracts.flower.address );
    
    let signerFlowerTokenId = await flower.flowerOwned(signer.address);


    // if you don't have an NFT, say and stop
    if (await signerFlowerTokenId == "0") {
      console.log("You don't own a Flower NFT, nothing to transfer away!");
    } else if (await flower.flowerOwned(banishAddress) != "0") {
      console.log("The banishAddress provided in this script already has a Flower NFT. Chose another one!");
    } else {
      console.log("Transfering away Flower NFT with Token ID:", signerFlowerTokenId);

      await flower.connect(signer).transferFrom(
        signer.address,
        banishAddress,
        await flower.flowerOwned(signer.address)
      );
    }

    console.log("Flower successfully expelled!")

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});