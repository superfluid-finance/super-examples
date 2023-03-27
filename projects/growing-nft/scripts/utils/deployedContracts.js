// Track your deployed contracts here so Hardhat scripts are using the right addresses

const hre = require("hardhat");

const flowerABI = require("../../artifacts/contracts/Flower.sol/Flower.json");
const waterABI = require("@superfluid-finance/ethereum-contracts/build/contracts/TestToken.json");
const superWaterABI = require("../../artifacts/@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol/ISuperToken.json")

const flowerAddress = "0x015b0C429B9cC32AB8470c3cb3E11AB548cBe996"
const waterAddress = "0x1669D97cFBFD77d46E81d7da49F389B5076E479C"
const superWaterAddress = "0x5A6FB18Cdf29fD3bc8D7e16930bf2c1875bec30f"


module.exports = {
    flower: {
        address: flowerAddress,
        contract: hre.ethers.getContractAt( flowerABI.abi, flowerAddress )
    },
    water: {
        address: waterAddress,
        contract: hre.ethers.getContractAt( waterABI.abi, waterAddress )
    },
    superWater: {
        address: superWaterAddress,
        contract: hre.ethers.getContractAt( superWaterABI.abi, superWaterAddress )    
    }
};