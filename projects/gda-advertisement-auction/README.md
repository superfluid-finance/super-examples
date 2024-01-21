# Welcome to the Advertisement Auction

### A basic example to get you started with the Superfluid's Distributions (General Distribution Agreement)

To get started with the updated version:

1. Navigate to the `foundry-tests`folder
    * `cd projects/gda-advertisement-auction/foundry-tests`
2. Create a .env file or simple export the environment variable RPC URL necessary for the Polygon Mumbai fork:
    * `export MUMBAI_RPC_URL=https://rpc-mumbai.maticvigil.com`
    Make sure to use a un RPC URL that is functional. Check [Chainlist](https://chainlist.org/chain/80001) for more URLs.
3. Install dependencies with specific commands:
    * `forge install superfluid-protocol-monorepo=https://github.com/superfluid-finance/protocol-monorepo@dev --no-commit`
    * `forge install https://github.com/OpenZeppelin/openzeppelin-contracts@v4.9.3 --no-commit`
4. Compile the contracts with `forge build`.
5. Run the test suite with `forge test`.
