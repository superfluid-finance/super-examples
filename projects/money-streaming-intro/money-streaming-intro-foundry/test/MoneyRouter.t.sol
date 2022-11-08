// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "ds-test/test.sol";

import "../src/MoneyRouter.sol";
import {ISuperfluid, ISuperToken, ISuperApp, ISuperfluidToken} from "../lib/ethereum-contracts/packages/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {IConstantFlowAgreementV1} from "../lib/ethereum-contracts/packages/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {ERC1820RegistryCompiled} from "../lib/ethereum-contracts/packages/ethereum-contracts/contracts/libs/ERC1820RegistryCompiled.sol";

import {TestToken} from "../lib/ethereum-contracts/packages/ethereum-contracts/contracts/utils/TestToken.sol";
import {SuperfluidFrameworkDeployer, TestGovernance, Superfluid, ConstantFlowAgreementV1, CFAv1Library, InstantDistributionAgreementV1, IDAv1Library, SuperTokenFactory} from "../lib/ethereum-contracts/packages/ethereum-contracts/contracts/utils/SuperfluidFrameworkDeployer.sol";

contract MoneyRouterTest is Test {
    //our money router contract we will interact with
    MoneyRouter public moneyRouter;

    //superfluid protocol host
    ISuperfluid public host;
    //superfluid protocol cfa
    IConstantFlowAgreementV1 public cfa;
    //dai, daix
    TestToken public dai;
    ISuperToken public daix;
    //accounts which will interact w contract
    address public account1;
    address public account2;

    //CFA library which will be used to create, update, delete stremas
    using CFAv1Library for CFAv1Library.InitData;
    CFAv1Library.InitData public cfaV1;

    //Superfluid Framework contracts
    struct Framework {
        TestGovernance governance;
        Superfluid host;
        ConstantFlowAgreementV1 cfa;
        CFAv1Library.InitData cfaLib;
        InstantDistributionAgreementV1 ida;
        IDAv1Library.InitData idaLib;
        SuperTokenFactory superTokenFactory;
    }

    SuperfluidFrameworkDeployer.Framework sf;

    function setUp() public {
        //ERC20 registry - must exist in test environment before we deploy framework
        vm.etch(ERC1820RegistryCompiled.at, ERC1820RegistryCompiled.bin);

        //deploying the framework
        SuperfluidFrameworkDeployer sfd = new SuperfluidFrameworkDeployer();
        //calling get framework to get contracts & initialize sf variable
        sf = sfd.getFramework();
        //initialize accounts and contract variables
        account1 = vm.addr(1);
        account2 = vm.addr(2);
        host = sf.host;
        cfa = sf.cfa;
        cfaV1 = CFAv1Library.InitData(host, cfa);
        //deploying a new token using Superfluid Framework Deployer
        (, daix) = sfd.deployWrapperSuperToken("fake dai token", "DAI", 18, 1000000000000000000000);

        //mint and upgrade tokens
        vm.startPrank(account1);
        dai = TestToken(daix.getUnderlyingToken());
        dai.mint(account1, 100000000000000000);
        dai.approve(address(daix), 100000000000000000);
        daix.upgrade(100000000000000000);
        vm.stopPrank();
        moneyRouter = new MoneyRouter(host, account1);

        vm.prank(account1);
        daix.transfer(address(moneyRouter), 50000000000000000);
    }
}

contract MoneyRouterDeployment is MoneyRouterTest {
    function testDeployment() public {
        setUp();
        //make sure contract was deployed properly
        assertEq(moneyRouter.owner(), account1, "wrong owner");
        assertEq(daix.balanceOf(account1), 50000000000000000);
        assertTrue(true);
    }
}

contract MoneyRouterFlowTests is MoneyRouterDeployment {
    //tests the operation of create, update, and delete flow into contract
    function testCreateFlowsIntoContract() public {
        setUp();

        vm.startPrank(account1);
        sf.cfaV1Forwarder.grantPermissions(daix, address(moneyRouter));
        moneyRouter.createFlowIntoContract(daix, 30000000);
        (, int96 checkCreatedFlowRate, , ) = sf.cfa.getFlow(daix, account1, address(moneyRouter));
        assertEq(30000000, checkCreatedFlowRate);

        moneyRouter.updateFlowIntoContract(daix, 60000000);
        (, int96 checkUpdatedFlowRate, , ) = sf.cfa.getFlow(daix, account1, address(moneyRouter));
        assertEq(60000000, checkUpdatedFlowRate);

        moneyRouter.deleteFlowIntoContract(daix);
        (, int96 checkDeletedFlowRate, , ) = sf.cfa.getFlow(daix, account1, address(moneyRouter));
        assertEq(0, checkDeletedFlowRate);
        vm.stopPrank();
    }

    //tests the operation of creating, updating, and deleting flows into contract
    function testCreateFlowsFromContract() public {
        setUp();

        vm.startPrank(account1);
        moneyRouter.createFlowFromContract(daix, account2, 30000000);
        (, int96 checkCreatedFlowRate, , ) = sf.cfa.getFlow(daix, address(moneyRouter), account2);
        assertEq(30000000, checkCreatedFlowRate);

        moneyRouter.updateFlowFromContract(daix, account2, 60000000);
        (, int96 checkUpdatedFlowRate, , ) = sf.cfa.getFlow(daix, address(moneyRouter), account2);
        assertEq(60000000, checkUpdatedFlowRate);

        moneyRouter.deleteFlowFromContract(daix, account2);
        (, int96 checkDeletedFlowRate, , ) = sf.cfa.getFlow(daix, address(moneyRouter), account2);
        assertEq(0, checkDeletedFlowRate);
    }
}
