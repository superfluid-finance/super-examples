# Gelato Vesting Automation Example

## About

A super simple project which utilizes Superfluid Vesting Scheduler and Gelato to automate vesting start and end tasks.

## Live Examples on Mumbai

A live example of a vesting automation contract has been deployed here: https://mumbai.polygonscan.com/address/0x633B1C635a20006455532bB095C369750E4282d1

-   It is set for DAIx token vesting

You can find the deployed Vesting Scheduler Contract on Mumbai here: https://mumbai.polygonscan.com/address/0x2a00b420848d723a74c231b559c117ee003b1829

## Built With

-   [@superfluid-finance/ethereum-contracts](https://www.npmjs.com/package/@superfluid-finance/ethereum-contracts)
-   [@superfluid-finance/sdk-core](https://www.npmjs.com/package/@superfluid-finance/sdk-core)
-   [foundry](https://github.com/foundry-rs/foundry)
-   [Hardhat](https://hardhat.org/)
-   [Gelato Ops](https://app.gelato.network/)

## TODO

-   [x] Example Vesting Automation Contract
-   [x] Deploy scripts
-   [x] Interactivity Scripts
-   [x] README completed
-   [ ] Tests Ready

## NOTE

This project is meant for demonstration purposes only. We recommend writing a full test suite and customizing to fit individual use cases. Also note that some foundry scaffolding is here if you want it, but this guide assumes you'll use hardhat instead.

## Prerequisites

In order to run this project, you need to have the following dependencies installed on your computer:

-   [yarn](https://yarnpkg.com/getting-started/install) or you can just use npm, but you'll need to change up the `Makefile` slightly.

## Project Setup

To set up the project run the following command:

```ts
yarn // installing the node_modules
```

```ts
yarn compile // compiling with hardhat the project
```

## Deploying the Contract & Creating Gelato Tasks

#### For running this on a live test network

Copy the .env.template--> and enter your private key, rpc URL and Etherscan if you'd like to verify the vesting automation contract

### Contract deployment

Constructor Params:

-   Vesting Token: each vesting automation contract is set to only support a single token
-   Automate: the address of the deployed Gelato Automate contract
-   PrimaryFundsOwner: A 'primary owner' address who has the ability to fund the contract with native tokens for the execution of each automation (and then subsequently withdraw those funds). This owner may add other owners.
-   Vesting Scheduler: the address of the previously deployed superfluid vesting scheduler contract

You must set your own custom params inside of the deploy script.

#### Another Important Note

-   For the vesting automation contract to work properly, it needs to be funded with the native asset required by gelato to execute each transaction at a future date
-   This deploy script will fund the contract with a small amount of MATIC, but you should seek to properly manage the funds within the contract according to Gelato Guidelines: https://docs.gelato.network/developer-services/automate/paying-for-your-transactions
-   Note that there is built in access control which allows 'owners' to manage the funds within the contract

### Steps

```ts
yarn hardhat run ./scripts/deployVestingAutomation.ts --network mumbai // change 'mumbai' to your network of choice
```

```ts
Vesting Automation deployed successfully at:  0x123...
```

We will copy the deployed address into our createVestingTask.ts script for later usage. For example:

```ts
const superfluidVestingAutomatorMumbai =
    "0x633B1C635a20006455532bB095C369750E4282d1"
```

We will now create a vesting schedule. This can be done either on a block explorer or with the createVestingSchedule.ts script.
Note that you can find all Vesting Scheduler addresses here: https://docs.superfluid.finance/superfluid/developers/networks.

-   You can find example params for creating a vesting schedule in the createVestingSchedule.ts script
-   A full guide on the superfluid vesting scheduler can be found here: https://docs.superfluid.finance/superfluid/developers/automations/vesting-scheduler

```ts
yarn hardhat run ./scripts/createVestingSchedule.ts --network mumbai // change 'mumbai' to your network of choice
```

If the above operation succeeds, you can then create a vesting automation task.

-   This will create an automation for both the start and end of vesting

```ts
yarn hardhat run ./scripts/createVestingAutomation.ts --network mumbai // change 'mumbai' to your network of choice
```

## Questions?

-   Contact the #dev-support channel in the Superfluid discord
