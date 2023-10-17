## Hardhat + Ethers V5 Superfluid Deployment Example

This project illustrates the recommend way of deploying the Superfluid protocol in a local testing environment for testing with Hardhat + Ethers V5. We utilize the `deployTestFramework` function from the `deploy-test-framework` script to do this.

In this example, we will illustrate the deployment process which deploys the full Superfluid Framework as well as a Wrapper Super Token, Native Super Token and Pure Super Token.

### Prerequisites

- npm / yarn / pnpm: a javascript package manager

1. In an existing hardhat + ethers v5 project, install the necessary dependencies:

    ```bash
    pnpm add -D @superfluid-finance/ethereum-contracts
    ```

> NOTE: If you are starting from a fresh project, run `npx hardhat init` and create a typescript project. Take a look at the package.json and remove any dependencies added by hardhat-the newer packages utilize ethers v6 under the hood and therefore will not work.

2. Modify `tsconfig.json`:

- Add `"include": ["scripts", "hardhat.config.ts"]`

> NOTE: You want to add `"tests"` and any other folder you are using hardhat-ethers in.

3. Take a look at 