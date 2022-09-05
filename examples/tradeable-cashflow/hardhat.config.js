require("@nomiclabs/hardhat-truffle5")
require("@nomiclabs/hardhat-ethers")
require("@nomiclabs/hardhat-etherscan");
require("hardhat-deploy")

require("dotenv").config();
// const GAS_LIMIT = 8000000;
//  const defaultNetwork = 'kovan';

module.exports = {
    solidity: {
        version: "0.8.14",
        settings: {
            optimizer: {
                enabled: true
            }
        }
    },
    namedAccounts: {
        deployer: 0,
        alice: 1
    },
    networks: {
        goerli: {
          url: process.env.GOERLI_URL,
          accounts: {
            mnemonic: process.env.MNEMONIC,
            initialIndex: 0,
            count: 10,
          }
        },
    },
    etherscan: {
        apiKey: process.env.ETHERSCAN_API_KEY,
    }
}
