// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
// import "../lib/forge-std/src/console.sol";
import "forge-std/console.sol";
// import "../lib/forge-std/console.sol";
// import "./lib/forge-std/console.sol";
import "ds-test/test.sol";

import "../src/MoneyRouter.sol";
import {ISuperfluid, ISuperToken, ISuperApp} from "../lib/ethereum-contracts/packages/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { ERC1820RegistryCompiled } from "../lib/ethereum-contracts/packages/ethereum-contracts/contracts/libs/ERC1820RegistryCompiled.sol";
// import {SuperfluidFrameworkDeployer} from "../lib/ethereum-contracts/packages/ethereum-contracts/contracts/utils/SuperfluidFrameworkDeployer.sol";
import {TestToken} from "../lib/ethereum-contracts/packages/ethereum-contracts/contracts/utils/TestToken.sol";
import {
    SuperfluidFrameworkDeployer,
    TestGovernance,
    Superfluid,
    ConstantFlowAgreementV1,
    CFAv1Library,
    InstantDistributionAgreementV1,
    IDAv1Library,
    SuperTokenFactory
} from "../lib/ethereum-contracts/packages/ethereum-contracts/contracts/utils/SuperfluidFrameworkDeployer.sol";

contract MoneyRouterTest is Test {
    MoneyRouter public moneyRouter;

    SuperfluidFrameworkDeployer public sfDeployer;
    SuperfluidFrameworkDeployer.Framework public sfFramework;
    ISuperfluid public host;
    TestToken public dai;
    ISuperToken public daix;
    address public account1;
    address public account2;



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

        vm.etch(ERC1820RegistryCompiled.at, ERC1820RegistryCompiled.bin);


        SuperfluidFrameworkDeployer sfd = new SuperfluidFrameworkDeployer();
        sf = sfd.getFramework();

        account1 = vm.addr(1);
        account2 = vm.addr(2);
        sfDeployer = new SuperfluidFrameworkDeployer();
        sfFramework = sfDeployer.getFramework();
        host = ISuperfluid(sfFramework.host);

        ( ,daix ) = sfd.deployWrapperSuperToken(
            "fake dai token",
            "DAI",
            18,
            1000000000000000000000
        );

        vm.startPrank(account1);
        dai = TestToken(daix.getUnderlyingToken());
        dai.mint(account1, 100000000000000000);
        dai.approve(address(daix), 100000000000000000);
        daix.upgrade(100000000000000000);
        vm.stopPrank();

        moneyRouter = new MoneyRouter(host, account1);

        vm.startPrank(account1);
        daix.transfer(address(moneyRouter), 50000000000000000);
        // sf.cfaV1Forwarder.createFlow(daix, account1, address(moneyRouter), 51235235, "0x");
        vm.stopPrank();
    }
}

contract MoneyRouterDeployment is MoneyRouterTest {

    function testDeployment() public {
        setUp();
        
        assertEq(moneyRouter.owner(), account1, "wrong owner");
        assertEq(daix.balanceOf(account1), 50000000000000000);
        assertTrue(true);
    }

    // function testSetNumber(uint256 x) public {
    //     counter.setNumber(x);
    //     assertEq(counter.number(), x);
    // }
}


