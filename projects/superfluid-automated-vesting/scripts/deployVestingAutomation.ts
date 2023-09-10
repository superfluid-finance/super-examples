import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"

import hre, { ethers } from "hardhat"
import { VestingAutomation__factory } from "../typechain-types/factories/src/VestingAutomation__factory"
import { getDeployer } from "./Helpers"
import { Framework } from "@superfluid-finance/sdk-core"

const gelatoAutomateMumbai = "0xB3f5503f93d5Ef84b06993a1975B9D21B962892F"
const superfluidVestingSchedulerMumbai =
    "0x2a00b420848D723A74c231B559C117Ee003B1829" // can find this at docs.superfluid.finance

async function main() {
    const provider = new ethers.providers.JsonRpcProvider(
        process.env.MUMBAI_URL
    )
    try {
        let deployer: SignerWithAddress = await getDeployer(hre)
        let nonce = await deployer.getTransactionCount()

        let sf = await Framework.create({
            chainId: 80001, // note - need to change if you don't want to use mumbai
            provider
        })

        let daix = await sf.loadSuperToken("fDAIx")

        console.log("DAIx Address", daix.address)

        const vestingAutomator = await new VestingAutomation__factory(
            deployer
        ).deploy(
            daix.address,
            gelatoAutomateMumbai,
            deployer.address,
            superfluidVestingSchedulerMumbai,
            { nonce: nonce, gasLimit: 10000000 }
        )

        let initialEth = hre.ethers.utils.parseEther("0.05")

        await deployer.sendTransaction({
            to: vestingAutomator.address,
            value: initialEth,
            gasLimit: 10000000,
            nonce: nonce + 1
        })

        console.log(
            "Vesting Automator deployed successfully at: ",
            vestingAutomator.address
        )
    } catch (err) {
        console.error(err)
    }
}

main()
    .then(() => process.exit(0))
    .catch(err => {
        console.error(err)
        process.exit(1)
    })
