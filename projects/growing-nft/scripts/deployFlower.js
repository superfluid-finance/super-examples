// Deploys Flower NFT contract

const hre = require("hardhat");

async function main() {

  const Flower = await hre.ethers.getContractFactory("Flower");
  const flower = await Flower.deploy(
    [ // Pinned flower-metadatas JSON file
      "ipfs://QmYUXy3JjoCjx1Fji71v9pPAWs3kAdrhBtUvVJw6m89g4A/plant1.json",
      "ipfs://QmYUXy3JjoCjx1Fji71v9pPAWs3kAdrhBtUvVJw6m89g4A/plant2.json",
      "ipfs://QmYUXy3JjoCjx1Fji71v9pPAWs3kAdrhBtUvVJw6m89g4A/plant3.json"
    ],
    [
      hre.ethers.utils.parseEther("10"),
      hre.ethers.utils.parseEther("10"),
      hre.ethers.utils.parseEther("10")
    ],
    "0x875Fa8aCaAe9fD57De678f9e52dF324B6279FF58" // WATERx address
  );

  await flower.deployed();

  console.log(
    `Flower Contract deployed to ${flower.address}\nMake sure to update the address in scripts/utils/deployedContracts.js`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});