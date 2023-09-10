const hre = require("hardhat")

const goerliHostAddress = "0x22ff293e14F1EC3A09B137e9e06084AFd63adDF9"
const goerliFDAIXAddress = "0xF2d68898557cCb2Cf4C10c3Ef2B034b2a69DAD00"

const name = "Water"
const symbol = "WATER"
const initDecimals = 18
const mintLimit = hre.ethers.constants.MaxUint256

module.exports = [name, symbol, initDecimals, mintLimit]

// npx hardhat verify --network goerli --constructor-args arguments-testtoken-goerli.js [contractAddress]
