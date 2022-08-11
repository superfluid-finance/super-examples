// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.14;

// This is a hack to ensure the protocol is deployed properly in the testing script. The problem is,
// the `InstantDistributionAgreementV1` contract uses an external contract, the
// `SlotsBitmapLibrary`. The only way Hardhat facilitates external library linking is via contract
// artifacts. However, unless the `InstantDistributionAgreementV1` contract is explicitly imported
// into the project, it won't be compiled and the artifact won't be generated.

// Hardhat has a dependency compiler extension, but developers have reported issues with usage in
// Node 14. This should go away with the publishing of the Superfluid hardhat deployer.

// https://hardhat.org/hardhat-runner/plugins/nomiclabs-hardhat-ethers#library-linking

import {InstantDistributionAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/agreements/InstantDistributionAgreementV1.sol";
