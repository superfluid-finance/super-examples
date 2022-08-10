require("@nomiclabs/hardhat-waffle")

module.exports = {
    solidity: {
        version: "0.8.14",
        settings: {
            optimizer: {
                enabled: true
            }
        }
    },
    networks: {
        hardhat: {
            blockGasLimit: 100000000 // REQUIRED for superfluidFrameworkDeployer
        }
    }
}
