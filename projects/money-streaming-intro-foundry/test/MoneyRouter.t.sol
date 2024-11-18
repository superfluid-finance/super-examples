// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "forge-std/Test.sol";

import { ISuperfluid, ISuperToken, IConstantFlowAgreementV1, ISuperApp } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { ERC1820RegistryCompiled } from "@superfluid-finance/ethereum-contracts/contracts/libs/ERC1820RegistryCompiled.sol";
import { TestToken } from "@superfluid-finance/ethereum-contracts/contracts/utils/TestToken.sol";
import { SuperfluidFrameworkDeployer } from "@superfluid-finance/ethereum-contracts/contracts/utils/SuperfluidFrameworkDeployer.sol";

import "../src/MoneyRouter.sol";

contract MoneyRouterTest is Test {

    MoneyRouter public moneyRouter;

    ISuperfluid public host;
    IConstantFlowAgreementV1 public cfa;
    TestToken public dai;
    ISuperToken public daix;
    address public account1;
    address public account2;

    SuperfluidFrameworkDeployer.Framework sf;

    function setUp() public {
        vm.etch(ERC1820RegistryCompiled.at, ERC1820RegistryCompiled.bin);

        SuperfluidFrameworkDeployer sfd = new SuperfluidFrameworkDeployer();
        sfd.deployTestFramework();
        sf = sfd.getFramework();
        account1 = vm.addr(1);
        account2 = vm.addr(2);
        host = sf.host;
        cfa = sf.cfa;
        (dai , daix) = sfd.deployWrapperSuperToken("DAI", "DAI", 18, 100000000000000000000000000000, account1);

        vm.startPrank(account1);
        dai = TestToken(daix.getUnderlyingToken());
        dai.mint(account1, 100000000000000000);
        dai.approve(address(daix), 100000000000000000);
        daix.upgrade(100000000000000000);
        vm.stopPrank();
        moneyRouter = new MoneyRouter(account1);

        vm.prank(account1);
        daix.transfer(address(moneyRouter), 50000000000000000);
    }
}

contract MoneyRouterDeployment is MoneyRouterTest {
    function testDeployment() public {
        setUp();

        assertEq(moneyRouter.owner(), account1, "wrong owner");
        assertEq(daix.balanceOf(account1), 50000000000000000);
        assertTrue(true);
    }
}

contract MoneyRouterFlowTests is MoneyRouterDeployment {
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
