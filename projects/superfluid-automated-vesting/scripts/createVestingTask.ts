import { Framework } from "@superfluid-finance/sdk-core"
import { getDeployer, receiver } from "./Helpers"
import hre, { ethers } from "hardhat"
import { VestingAutomation__factory } from "../typechain-types/factories/src/VestingAutomation__factory"
import { VestingAutomation } from "../typechain-types/src/VestingAutomation"

const superfluidVestingAutomatorMumbai =
    "0x633B1C635a20006455532bB095C369750E4282d1"

const createVestingTask = async () => {
    try {
        let deployer = await getDeployer(hre)

        let vestingAutomator = VestingAutomation__factory.connect(
            superfluidVestingAutomatorMumbai,
            deployer
        ) as VestingAutomation

        let txn = await vestingAutomator.createVestingTask(
            deployer.address,
            "0x796Cf26eE956f790920D178AAc373c90DA7b8f79"
        )

        console.log("Transaction broadcasted, waiting...")
        await txn.wait().then(console.log)
    } catch (err) {
        console.error(err)
    }
}

;(async () => {
    await createVestingTask()
})()
