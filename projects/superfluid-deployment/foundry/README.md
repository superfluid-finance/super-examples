## Foundry Superfluid Deployment Example

This project illustrates the recommend way of deploying the Superfluid protocol in a local testing environment for testing with Foundry. We utilize the `SuperfluidFrameworkDeployer` contract to do this.

In this example, we will illustrate the deployment process which deploys the full Superfluid Framework as well as a Wrapper Super Token, Native Super Token and Pure Super Token.

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)

### Steps

> NOTE: After each step, run: `forge build` or simply run `forge build --watch` (or `forge build -w`) after step 1.

1. In a new directory, initialize a new Foundry project:

    ```bash
    forge init --no-commit
    ```
    > NOTE: Only use `--no-commit` if you don't want it the installer to do an initial commit.

2. Install dependencies:
    a. the Superfluid Protocol Monorepo as a git submodule using forge:
    ```bash
    forge install superfluid-protocol-monorepo=superfluid-finance/protocol-monorepo@dev --no-commit
    ```
    b. OpenZeppelin contracts as a git submodule using forge:
    ```
    forge install OpenZeppelin@v4.9.3 --no-commit
    ```
    
    > NOTE: OpenZeppelin@v.4.9.3 is a necessary dependency because the Superfluid protocol uses OpenZeppelin@v4.9.3 and not the latest version.

3. Ensure you have the correct remappings.

    a. Place this in a `remappings.txt` file:
    ```bash
    ds-test/=lib/forge-std/lib/ds-test/src/
    forge-std/=lib/forge-std/src/
    @superfluid-finance/ethereum-contracts/=lib/superfluid-protocol-monorepo/packages/ethereum-contracts/
    @openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/
    erc4626-tests/=lib/openzeppelin-contracts/lib/erc4626-tests/
    openzeppelin-contracts/=lib/openzeppelin-contracts/
    ```
    > NOTE: You can use `forge remappings > remappings.txt` as well, but you'll need to change the remappings for `superfluid-contracts/` to point to `ethereum-contracts/contracts`.

    b. Also add this to your foundry.toml file:
    ```
    remappings = [
        "ds-test/=lib/forge-std/lib/ds-test/src/",
        "forge-std/=lib/forge-std/src/",
        "@superfluid-finance/ethereum-contracts/=lib/superfluid-protocol-monorepo/packages/ethereum-contracts/",
        "@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/",
        "erc4626-tests/=lib/openzeppelin-contracts/lib/erc4626-tests/",
        "openzeppelin-contracts/=lib/openzeppelin-contracts/"
    ]
    ```

4. Look at the `setUp` function in [`test/Superfluid.t.sol`](test/Superfluid.t.sol). We will examine each line:

- `vm.etch(ERC1820RegistryCompiled.at, ERC1820RegistryCompiled.bin);`: this is a special function that etches the 1820 bytecode to the canonical 1820 address across all networks. We use ERC1820 for registering SuperTokens for ERC777.
- `deployer = new SuperfluidFrameworkDeployer();`: this creates a new instance of the `SuperfluidFrameworkDeployer` contract.
- `deployer.deployTestFramework();`: this deploys the Superfluid Framework to the local foundry test environment.
- `sf = deployer.getFramework();`: this gets the Superfluid Framework instance from the `SuperfluidFrameworkDeployer` contract, this is a struct with the Superfluid Framework contracts.

5. Take a look at the test functions below the `setUp` function in [`test/Superfluid.t.sol`](test/Superfluid.t.sol) to see how the different types of SuperTokens are deployed.