const hre = require("hardhat")

const stageAmounts = [
    hre.ethers.utils.parseEther("10"),
    hre.ethers.utils.parseEther("10"),
    hre.ethers.utils.parseEther("10")
]
const acceptedToken = "0x875Fa8aCaAe9fD57De678f9e52dF324B6279FF58"
const host = "0x22ff293e14F1EC3A09B137e9e06084AFd63adDF9"
const cfa = "0xEd6BcbF6907D4feEEe8a8875543249bEa9D308E8"

module.exports = [stageAmounts, acceptedToken]

//// npx hardhat verify --network goerli --constructor-args arguments-flower-goerli.js [contractaddress]
