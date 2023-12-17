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
        account2= address(0x61fFC0072D66cE2bC3b8D7654BF68690b2d7fDc4);
        vm.prank(account1);
        daix.transfer(address(adSpotContract), 1e18);
        vm.stopPrank();
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

    function testFlowUpdate() public {
        int96 flowRate = int96(1000); // example flow rate

        // Create a flow from account1 to the adSpotContract
        vm.startPrank(account1);
        daix.createFlow(address(adSpotContract), flowRate);
        vm.stopPrank();

        // Verify that the highest bidder and flow rate are updated correctly
        assertEq(adSpotContract.getHighestBidder(), account1, "Account1 should be the highest bidder");
        assertEq(adSpotContract.getHighestFlowRate(), flowRate, "Highest flow rate should match the set flow rate");

        vm.startPrank(account1);
        daix.updateFlow(address(adSpotContract), 2*flowRate);
        vm.stopPrank();

        // Verify that the flow rate is updated correctly
        assertEq(adSpotContract.getHighestFlowRate(), 2*flowRate, "Highest flow rate should match the set flow rate");

    }

    function testFlowDeletion() public {
        int96 flowRate = int96(1000); // example flow rate

        // Create a flow from account1 to the adSpotContract
        vm.startPrank(account1);
        daix.createFlow(address(adSpotContract), flowRate);
        vm.stopPrank();

        // Verify that the highest bidder and flow rate are updated correctly
        assertEq(adSpotContract.getHighestBidder(), account1, "Account1 should be the highest bidder");
        assertEq(adSpotContract.getHighestFlowRate(), flowRate, "Highest flow rate should match the set flow rate");

        vm.startPrank(account1);
        daix.deleteFlow(account1, address(adSpotContract));
        vm.stopPrank();

        // Verify that the highest bidder and flow rate are updated correctly
        assertEq(adSpotContract.getHighestBidder(), address(0), "Initial highest bidder should be address 0");
        assertEq(adSpotContract.getHighestFlowRate(), 0, "Highest flow rate should match the set flow rate");

    }

    function testHigherBidd() public {
        int96 flowRate = int96(1000); // example flow rate

        // Create a flow from account1 to the adSpotContract
        vm.startPrank(account1);
        daix.createFlow(address(adSpotContract), flowRate);
        vm.stopPrank();

        // Verify that the highest bidder and flow rate are updated correctly
        assertEq(adSpotContract.getHighestBidder(), account1, "Account1 should be the highest bidder");
        assertEq(adSpotContract.getHighestFlowRate(), flowRate, "Highest flow rate should match the set flow rate");

        // Create a flow from account2 to the adSpotContract
        vm.startPrank(account2);
        daix.createFlow(address(adSpotContract), flowRate+2);
        vm.stopPrank();

        // Verify that the highest bidder and flow rate are updated correctly
        assertEq(adSpotContract.getHighestBidder(), account2, "Account2 should be the highest bidder");
        assertEq(adSpotContract.getHighestFlowRate(), flowRate+2, "Highest flow rate should match the set flow rate");

    }

    function testNFTSetting() public {
        int96 flowRate = int96(1000); // example flow rate

        // Create a flow from account1 to the adSpotContract
        vm.startPrank(account1);
        daix.createFlow(address(adSpotContract), flowRate);
        vm.stopPrank();

        // Verify that the highest bidder and flow rate are updated correctly
        assertEq(adSpotContract.getHighestBidder(), account1, "Account1 should be the highest bidder");
        assertEq(adSpotContract.getHighestFlowRate(), flowRate, "Highest flow rate should match the set flow rate");

        // Set an NFT to showcase
        vm.startPrank(account1);
        adSpotContract.setNftToShowcase(address(this), 1);
        vm.stopPrank();

        // Verify that the NFT address and token ID are updated correctly
        assertEq(adSpotContract.getNftAddress(), address(this), "NFT address should be this contract");
        assertEq(adSpotContract.getNftTokenId(), 1, "NFT token ID should be 1");

    }

    function testOwnerUnitsFirstTime() public {
        int96 flowRate = int96(1000); // example flow rate

        // Create a flow from account1 to the adSpotContract
        vm.startPrank(account1);
        daix.createFlow(address(adSpotContract), flowRate);
        vm.stopPrank();

        // Verify that the highest bidder and flow rate are updated correctly
        assertEq(adSpotContract.getHighestBidder(), account1, "Account1 should be the highest bidder");
        assertEq(adSpotContract.getHighestFlowRate(), flowRate, "Highest flow rate should match the set flow rate");

        // Verify that the owner's shares are updated correctly
        assertEq(adSpotContract.getOwnerShares(), 1, "Owner's shares should be 1e18");
    }

    function testMembersUnits() public {
        int96 flowRate = int96(1000); // example flow rate

        // Create a flow from account1 to the adSpotContract
        vm.startPrank(account1);
        daix.createFlow(address(adSpotContract), flowRate);
        vm.stopPrank();

        // Verify that the highest bidder and flow rate are updated correctly
        assertEq(adSpotContract.getHighestBidder(), account1, "Account1 should be the highest bidder");
        assertEq(adSpotContract.getHighestFlowRate(), flowRate, "Highest flow rate should match the set flow rate");

        // Verify that the owner's shares are updated correctly
        assertEq(adSpotContract.getOwnerShares(), 1, "Owner's shares should be 1");

        // Create a flow from account2 to the adSpotContract
        vm.startPrank(account2);
        daix.createFlow(address(adSpotContract), flowRate+2);
        vm.stopPrank();

        // Verify that the owner's shares are updated correctly
        assertEq(adSpotContract.getOwnerShares(), adSpotContract.getTotalShares()/2, "Owner's shares should be half of total shares");
        assertEq(adSpotContract.getOwnerShares(), adSpotContract.getMemberShares(account1), "Owner's shares should be same as account1's shares");
    }

    testAdvancedMembersUnits() public {
        int96 flowRate = int96(1000); // example flow rate

        // Create a flow from account1 to the adSpotContract
        vm.startPrank(account1);
        daix.createFlow(address(adSpotContract), flowRate);
        vm.stopPrank();

        // Verify that the highest bidder and flow rate are updated correctly
        assertEq(adSpotContract.getHighestBidder(), account1, "Account1 should be the highest bidder");
        assertEq(adSpotContract.getHighestFlowRate(), flowRate, "Highest flow rate should match the set flow rate");

        // Verify that the owner's shares are updated correctly
        assertEq(adSpotContract.getOwnerShares(), 1, "Owner's shares should be 1");

        // Create a flow from account2 to the adSpotContract
        vm.startPrank(account2);
        daix.createFlow(address(adSpotContract), flowRate+2);
        vm.stopPrank();

        // Verify that the owner's shares are updated correctly
        assertEq(adSpotContract.getOwnerShares(), adSpotContract.getTotalShares()/2, "Owner's shares should be half of total shares");
        assertEq(adSpotContract.getOwnerShares(), adSpotContract.getMemberShares(account1), "Owner's shares should be same as account1's shares");

        // Create a flow from account2 to the adSpotContract
        vm.startPrank(account1);
        daix.createFlow(address(adSpotContract), flowRate+2);
        vm.stopPrank();

        // Verify that the owner's shares are updated correctly
        assertEq(adSpotContract.getOwnerShares(), adSpotContract.getTotalShares()/3, "Owner's shares should be 1/3 of total shares");
        assertEq(adSpotContract.getOwnerShares(), adSpotContract.getMemberShares(account1), "Owner's shares should be same as account1's shares");
        assertEq(adSpotContract.getOwnerShares(), adSpotContract.getMemberShares(account2), "Owner's shares should be same as account2's shares");

    }


}
