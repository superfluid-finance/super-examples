
import { Framework } from "@superfluid-finance/sdk-core";
import { getDeployer, receiver } from "./Helpers";
import hre, { ethers } from "hardhat";
import { VestingScheduler__factory } from "../typechain-types/factories/src/VestingScheduler__factory";
import { VestingScheduler } from "../typechain-types/src/VestingScheduler";

const superfluidVestingSchedulerMumbai = "0x2a00b420848D723A74c231B559C117Ee003B1829" // can find this at docs.superfluid.finance  

const createVestingSchedule = async () => {
    const provider = new ethers.providers.JsonRpcProvider(
        process.env.MUMBAI_URL
    )
    try {

        let sf = await Framework.create({
            chainId: 80001, // note - need to change if you don't want to use mumbai,
            provider
        });

        let daix = await sf.loadSuperToken("fDAIx");
     
        let deployer = await getDeployer(hre);

        let vestingScheduler = VestingScheduler__factory.connect(superfluidVestingSchedulerMumbai, deployer) as VestingScheduler;
        
        //note that this was just a sample
        let txn = await vestingScheduler.createVestingSchedule(
            daix.address,
            "0x796Cf26eE956f790920D178AAc373c90DA7b8f79",
            "1680310482",
            "1680656082",
            "10000000000000000",
            "2500000000000000",
            "1681692882",
            "0x" 
        );
        
        console.log("Transaction broadcasted, waiting...");
        await txn.wait().then(console.log)

    } catch (err) {
        console.error(err);
    }
};

(async () => {
    await createVestingSchedule();
})();
