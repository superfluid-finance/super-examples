require("@nomicfoundation/hardhat-toolbox")
require("@nomiclabs/hardhat-ethers")
require("dotenv").config()

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    solidity: "0.8.19",
    networks: {
        hardhat: {},
        polygon_mumbai: {
            url: `${process.env.MUMBAI_URL}`,
            accounts: [process.env.PRIVATE_KEY],
            blockGasLimit: 20000000,
            gasPrice: 55000000000 // 35 Gwei
        }
    },
    mocha: {
        timeout: 1000000000000000000
    },
    etherscan: {
        apiKey: {
            goerli: process.env.ETHERSCAN_KEY ?? ""
        }
    }
}
