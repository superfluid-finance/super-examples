

import { HardhatRuntimeEnvironment } from "hardhat/types";

export const CloseStreamAddress = "0x0e9F4638f89C6CF2DedC5E5CCe7fE264f85fD126";

export const receiver = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";

export const getDeployer = async (hre:HardhatRuntimeEnvironment) =>{
    const ethers = hre.ethers; 

    let network = hre.hardhatArguments.network;
    console.log(network);
    let deployer; 
    if (network == undefined) {
      network = hre.network.name;
    }


    if (network == 'localhost') {

      const accounts = await ethers.getSigners();
      deployer = accounts[0];
      console.log(deployer.address);
  
    } else {
        const accounts = await ethers.getSigners();
        deployer = accounts[0];
        console.log(deployer.address);
    //   const deployer_provider = hre.ethers.provider;
    //   const privKeyDEPLOYER = process.env['PRIVATE_KEY'] as BytesLike;
    //   const deployer_wallet = new Wallet(privKeyDEPLOYER);
    //   deployer = await deployer_wallet.connect(deployer_provider);
    }

    return deployer;
}