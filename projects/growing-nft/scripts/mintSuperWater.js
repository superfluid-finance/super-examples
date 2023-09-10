// Funds your wallet with many WATERx tokens

const hre = require("hardhat")
const deployedContracts = require("./utils/deployedContracts")

async function main() {
    let water = await deployedContracts.water.contract
    let waterx = await deployedContracts.superWater.contract

    const mintAmount = ethers.utils.parseEther("10000000000")

    const signer = await hre.ethers.getSigner() // receives minted WATER tokens

    console.log(
        `Minting ${ethers.utils.formatUnits(mintAmount)} WATERx to ${
            signer.address
        }`
    )

    await water.connect(signer).mint(signer.address, mintAmount)
    console.log("minted water")

    let approveTx = await water
        .connect(signer)
        .approve(waterx.address, mintAmount)
    await approveTx.wait()
    console.log("approved super water")

    let upgradeTx = await waterx.connect(signer).upgrade(mintAmount)
    await upgradeTx.wait()

    console.log(
        `Success! ${signer.address} WATERx Balance: ${await waterx.balanceOf(
            signer.address
        )}`
    )
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
    console.error(error)
    process.exitCode = 1
})
