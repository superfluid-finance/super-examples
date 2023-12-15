pragma solidity >=0.8.2 <0.9.0;

import "forge-std/Test.sol";
import {ISuperfluid, ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {TestGovernance, Superfluid, ConstantFlowAgreementV1, CFAv1Library, SuperTokenFactory} from "@superfluid-finance/ethereum-contracts/contracts/utils/SuperfluidFrameworkDeploymentSteps.sol";
import {SuperfluidFrameworkDeployer} from "@superfluid-finance/ethereum-contracts/contracts/utils/SuperfluidFrameworkDeployer.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {TestToken} from "@superfluid-finance/ethereum-contracts/contracts/utils/TestToken.sol";
import {AdSpotContract} from "../src/AdSpotContract.sol";

contract AdSpotContractTest is Test {
    using SuperTokenV1Library for ISuperToken;

    // Test contract instance
    AdSpotContract adSpotContract;
    //Set up your Superfluid framework
    SuperfluidFrameworkDeployer.Framework sf;
    address public account1;
    address public account2;
    ISuperToken daix;
    uint256 mumbaiFork;
    string MUMBAI_RPC_URL = vm.envString("MUMBAI_RPC_URL");


    function setUp() public {
        mumbaiFork = vm.createSelectFork(MUMBAI_RPC_URL);

        daix= ISuperToken(0x5D8B4C2554aeB7e86F387B4d6c00Ac33499Ed01f);
        adSpotContract = new AdSpotContract(daix);
        account1 = address(0x72343b915f335B2af76CA703cF7a550C8701d5CD);
    }

    function testInitialSetup() public {
        vm.selectFork(mumbaiFork);
        assertEq(vm.activeFork(), mumbaiFork);
        assertEq(address(adSpotContract.getAcceptedToken()), address(daix), "Accepted token should be daix");
        assertEq(adSpotContract.getOwner(), address(this), "Contract owner should be this contract");
        assertEq(adSpotContract.getHighestBidder(), address(0), "Initial highest bidder should be address 0");
    }

    function testFlowCreation() public {
        int96 flowRate = int96(1000); // example flow rate

        // Create a flow from account1 to the adSpotContract
        vm.startPrank(account1);
        daix.createFlow(address(adSpotContract), flowRate);
        vm.stopPrank();

        // Verify that the highest bidder and flow rate are updated correctly
        assertEq(adSpotContract.getHighestBidder(), account1, "Account1 should be the highest bidder");
        assertEq(adSpotContract.getHighestFlowRate(), flowRate, "Highest flow rate should match the set flow rate");
    }

    // Test creating a new flow to the contract
}
