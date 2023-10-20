import { ethers } from "hardhat";
import { deployTestFramework } from "@superfluid-finance/ethereum-contracts/dev-scripts/deploy-test-framework";
import testResolverArtifact from "@superfluid-finance/ethereum-contracts/build/hardhat/contracts/utils/TestResolver.sol/TestResolver.json";

async function main() {
  const [Deployer] = await ethers.getSigners();
  const {frameworkDeployer} = await deployTestFramework(process.env.HARDHAT_TEST_ACCOUNT_PRIVATE_KEY, ethers.provider);

  const framework = await frameworkDeployer.getFramework();

  const resolver = await ethers.getContractAt(
    testResolverArtifact.abi,
    framework.resolver
  );

  await frameworkDeployer
      .connect(Deployer)
      .deployWrapperSuperToken(
          "Fake DAI",
          "fDAI",
          18,
          ethers.parseUnits("1000000000000")
      );

  await frameworkDeployer
      .connect(Deployer)
      .deployNativeAssetSuperToken("Super ETH", "ETHx");

  await frameworkDeployer
      .connect(Deployer)
      .deployPureSuperToken(
          "Mr.Token",
          "MRx",
          ethers.parseUnits("1000000000000")
      );

    const fDAIAddress = await resolver.get("tokens.test.fDAI");
    const fDAIxAddress = await resolver.get("supertokens.test.fDAIx");
    const ethxAddress = await resolver.get("supertokens.test.ETHx");
    const mrxAddress = await resolver.get("supertokens.test.MRx");

    console.log("fDAI address", fDAIAddress);
    console.log("fDAIx address", fDAIxAddress);
    console.log("ETHx address", ethxAddress);
    console.log("MRx address", mrxAddress);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
