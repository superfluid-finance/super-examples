require("dotenv").config()

require("@nomiclabs/hardhat-etherscan")
require("@nomiclabs/hardhat-ethers")
require("@nomiclabs/hardhat-waffle")

task("accounts", "Prints the list of accounts", async (_, hre) => {
    const accounts = await hre.ethers.getSigners()

    for (const account of accounts) {
        console.log(account.address)
    }
})

module.exports = {
    solidity: "0.8.14",
    networks: {
        hardhat: {
            blockGasLimit: 100000000
        }
        // goerli: {
        //     url: process.env.GOERLI_URL || "",
        //     accounts: {
        //         mnemonic: process.env.MNEMONIC || "",
        //         initialIndex: 0,
        //         count: 10
        //     }
        // }
    },
    gasReporter: {
        enabled: process.env.REPORT_GAS !== undefined,
        currency: "USD"
    },
    etherscan: {
        apiKey: process.env.ETHERSCAN_API_KEY
    },
    mocha: {
        timeout: 50000000 // setting it very high so testing doesn't complain
    }
}
