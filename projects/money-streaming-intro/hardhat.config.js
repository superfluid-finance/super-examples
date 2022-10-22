require("dotenv").config()

require("@nomiclabs/hardhat-etherscan")
require("@nomiclabs/hardhat-ethers")
require("hardhat-gas-reporter")
require("solidity-coverage")

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
        //     accounts:
        //         process.env.PRIVATE_KEY !== undefined
        //             ? [process.env.PRIVATE_KEY]
        //             : []
        // }
    },
    gasReporter: {
        enabled: process.env.REPORT_GAS !== undefined,
        currency: "USD"
    },
    etherscan: {
        apiKey: process.env.ETHERSCAN_API_KEY
    }
}
