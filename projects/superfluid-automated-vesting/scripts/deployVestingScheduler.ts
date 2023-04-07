import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";


import hre, { ethers } from "hardhat";
import { VestingScheduler__factory } from "../typechain-types/factories/src/VestingScheduler__factory";
import { getDeployer } from "./Helpers";
import { Framework } from "@superfluid-finance/sdk-core";

const gelatoAutomateMumbai = "0xB3f5503f93d5Ef84b06993a1975B9D21B962892F";
const superfluidVestingSchedulerMumbai = "0x2a00b420848D723A74c231B559C117Ee003B1829" 

//NOTE - this should only be needed once.
async function main() {

    const provider = new ethers.providers.JsonRpcProvider(
        process.env.MUMBAI_URL
    )
    
    try {

        let sf = await Framework.create({
            chainId: 80001, // note - need to change if you don't want to use mumbai
            provider
        });

        console.log("Host Address", sf.settings.config.hostAddress);
        
        let deployer: SignerWithAddress = await getDeployer(hre);
        let nonce = await deployer.getTransactionCount();

        const scheduler = await new VestingScheduler__factory(deployer).deploy(sf.settings.config.hostAddress, "0x", { nonce: nonce  ,gasLimit: 10000000});

        console.log('Vesting Scheduler deployed successfully at: ', scheduler.address)

    } catch (err) {
        console.error(err);
    }
}

main()
    .then(() => process.exit(0))
    .catch(err => {
        console.error(err);
        process.exit(1);
    });
