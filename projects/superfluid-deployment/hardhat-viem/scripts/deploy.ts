import { formatEther, parseEther } from "viem";
import hre from "hardhat";
import { deployTestFramework } from "@superfluid-finance/ethereum-contracts/dev-scripts/deploy-test-framework";
import testResolverArtifact from "@superfluid-finance/ethereum-contracts/build/hardhat/contracts/utils/TestResolver.sol/TestResolver.json";


async function main() {
  const {frameworkDeployer} = await deployTestFramework();

  const framework = await frameworkDeployer.getFramework();

  const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  const unlockTime = BigInt(currentTimestampInSeconds + 60);

  const lockedAmount = parseEther("0.001");

  const lock = await hre.viem.deployContract("Lock", [unlockTime], {
    value: lockedAmount,
  });

  console.log(
    `Lock with ${formatEther(
      lockedAmount
    )}ETH and unlock timestamp ${unlockTime} deployed to ${lock.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
