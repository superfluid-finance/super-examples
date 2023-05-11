// SPDX-License-Identifier: AGPLv3
// solhint-disable not-rely-on-time
pragma solidity ^0.8.17;

import { Test } from "forge-std/Test.sol";
import { Vm } from "forge-std/Vm.sol";
import "forge-std/console.sol";
import { ERC1820RegistryCompiled } from "@superfluid-finance/ethereum-contracts/contracts/libs/ERC1820RegistryCompiled.sol";
import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import { ISuperfluidToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import { ISuperTokenFactory } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperTokenFactory.sol";
import { IInstantDistributionAgreementV1 } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IInstantDistributionAgreementV1.sol";
import {
    CFAv1Library,
    ConstantFlowAgreementV1,
    ERC20PresetMinterPauser,
    Superfluid,
    SuperToken,
    SuperTokenFactory,
    SuperfluidFrameworkDeployer
} from "@superfluid-finance/ethereum-contracts/contracts/utils/SuperfluidFrameworkDeployer.sol";
import { VestingScheduler } from "../VestingScheduler.sol";
 

contract VestingSchedulerTest is Test {
    Vm private _vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    uint256 private constant INIT_TOKEN_BALANCE = type(uint128).max;
    uint256 private constant INIT_SUPER_TOKEN_BALANCE = type(uint64).max;
    address private constant receiver = address(2);
    
    address private constant sender = address(420);
    address[] private TEST_ACCOUNTS = [receiver, sender];
    string memory registrationKey = ""; // can be an empty string in dev or testnet deployments
    using CFAv1Library for CFAv1Library.InitData;
   

    SuperfluidFrameworkDeployer internal immutable sfDeployer;
    SuperfluidFrameworkDeployer.Framework internal sfFramework;
    Superfluid private _host;
    ConstantFlowAgreementV1 private _cfa;
    SuperTokenFactory private _superTokenFactory;
    ERC20PresetMinterPauser private _token;
    ISuperToken private _superToken;
    VestingScheduler private _vestingScheduler;

    /**************************************************************************
     * Setup Function
     *************************************************************************/

    constructor() {
        _vm.startPrank(sender);

        // Deploy ERC1820
        vm.etch(ERC1820RegistryCompiled.at, ERC1820RegistryCompiled.bin);

        sfDeployer = new SuperfluidFrameworkDeployer();
        sfFramework = sfDeployer.getFramework();
        _host = sfFramework.host;
        _cfa = sfFramework.cfa;
        _superTokenFactory = sfFramework.superTokenFactory;

        _vm.stopPrank();
    }

    function setUp() public {
        // Become sender
        _vm.startPrank(sender);

        // initialize underlying token
        _token = new ERC20PresetMinterPauser("Sade Token", "SADE");
        _superToken = _superTokenFactory.createERC20Wrapper(
            _token,
            18,
            ISuperTokenFactory.Upgradability.SEMI_UPGRADABLE,
            "Super Sade Token",
            "SADEx"
        );
        _vm.stopPrank();

        // mint tokens for accounts
        for (uint8 i = 0; i < TEST_ACCOUNTS.length; i++) {
            _vm.prank(sender);
            _token.mint(TEST_ACCOUNTS[i], INIT_TOKEN_BALANCE);
            _vm.startPrank(TEST_ACCOUNTS[i]);
            _token.approve(address(_superToken), INIT_TOKEN_BALANCE);
            _superToken.upgrade(INIT_TOKEN_BALANCE);
            _vm.stopPrank();
        }

        _vm.startPrank(sender);
        // initialize Simple ACL Close Resolver
        _vestingScheduler = new VestingScheduler(
           _host, registrationKey
        );

      

        _vm.stopPrank();
    }

    /**************************************************************************
     * Tests
     *************************************************************************/

    /**
     * Revert Tests
     */

    // Ops Tests
    function testCannotExecuteRightNow() public {
        // create a stream from sender to receiver
        _vm.startPrank(sender);
        sfFramework.cfaLib.createFlow(receiver, _superToken, 100);

        // fails because cannot execute yet
        _vm.expectRevert(OpsMock.CannotExecute.selector);

        ops.exec();
        _vm.stopPrank();
    }

    function testCannotCloseWithoutApproval() public {
        // create a stream from sender to receiver
        _vm.startPrank(sender);

        // move block.timestamp to 1 because it is currently at 0
        _vm.warp(block.timestamp + 1);

        sfFramework.cfaLib.createFlow(receiver, _superToken, 100);

        // warp to a time when it's acceptable to execute
        _vm.warp(block.timestamp + 14401);
        _vm.expectRevert(OpsMock.FailedExecution.selector);

        // still fail because of no flowOperator approval
        ops.exec();
    }

    function testCannotCloseBeforeEndTime() public {
        // create a stream from sender to receiver
        _vm.startPrank(sender);
        sfFramework.cfaLib.createFlow(receiver, _superToken, 100);

        // grant permissions so ops has full flow operator permissions
        _grantFlowOperatorPermissions(address(_superToken), address(ops));

        // fails because cannot execute yet
        _vm.expectRevert(OpsMock.CannotExecute.selector);

        ops.exec();
        _vm.stopPrank();
    }

}
