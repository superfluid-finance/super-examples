require("@nomiclabs/hardhat-ethers")

//kovan addresses - change if using a different network
const host = "0x22ff293e14F1EC3A09B137e9e06084AFd63adDF9"
const fUSDCx = "0x8aE68021f6170E5a766bE613cEA0d75236ECCa9a"

//your address here...
const owner = "0x3E536E5d7cB97743B15DC9543ce9C16C0E3aE10F"

//to deploy, run yarn hardhat deploy --network kovan

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { deploy } = deployments

    const { deployer } = await getNamedAccounts()
    console.log(deployer)

    await deploy("TradeableCashflow", {
        from: deployer,
        args: [owner, "Tradeable Cashflow", "TCF", host, fUSDCx],
        log: true
    })
}
module.exports.tags = ["TradeableCashflow"]
