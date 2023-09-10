// deploy a new WATER ERC20 token

const hre = require("hardhat")
const TestToken = require("@superfluid-finance/ethereum-contracts/build/contracts/TestToken.json")

async function main() {
    const Token = await hre.ethers.getContractFactory(
        TestToken.abi,
        TestToken.bytecode
    )
    const token = await Token.deploy(
        "Water",
        "WATER",
        "18",
        hre.ethers.constants.MaxUint256
    )

    await token.deployed()

    console.log(
        `Token Contract deployed to ${token.address}\nMake sure to update the address in scripts/utils/deployedContracts.js`
    )
    console.log(
        `Deploy a wrapper for this token at https://deploy-supertoken-deployment.vercel.app/`
    )
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
    console.error(error)
    process.exitCode = 1
})
