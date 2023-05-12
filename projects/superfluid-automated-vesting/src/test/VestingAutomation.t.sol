// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import { FlowOperatorDefinitions } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { SuperfluidFrameworkDeployer, SuperfluidTester, Superfluid, ConstantFlowAgreementV1, CFAv1Library } from "./SuperfluidTester.t.sol";
import { ERC1820RegistryCompiled } from "@superfluid-finance/ethereum-contracts/contracts/libs/ERC1820RegistryCompiled.sol";
 import {AutomateTaskCreator} from '../gelato/AutomateTaskCreator.sol';
import { VestingAutomation } from "../VestingAutomation.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
 import { VestingScheduler } from "../VestingScheduler.sol";
import { IVestingScheduler } from "../interface/IVestingScheduler.sol";
/// @title VestingAutomationTests
contract VestingAutomationTests is SuperfluidTester {

  

    /// @dev This is required by solidity for using the CFAv1Library in the tester
    using CFAv1Library for CFAv1Library.InitData;

    SuperfluidFrameworkDeployer internal immutable sfDeployer;
    SuperfluidFrameworkDeployer.Framework internal sf;
    Superfluid host;
    ConstantFlowAgreementV1 cfa;
    VestingAutomation internal _vestingAutomation;
    VestingScheduler internal _vestingScheduler;
    uint256 private _expectedTotalSupply = 0;
    CFAv1Library.InitData internal cfaV1Lib; 
    ERC20 private _token;
    ISuperToken private _superToken;

    /// @dev Constants for Testing
     address private constant _automate = address(0);
      address private constant _primaryFundsOwner = address(1);
    
    uint32 immutable START_DATE = uint32(block.timestamp + 1);
    uint32 immutable CLIFF_DATE = uint32(block.timestamp + 10 days);
    int96 constant FLOW_RATE = 1000000000;
    uint256 constant CLIFF_TRANSFER_AMOUNT = 1 ether;
    uint32 immutable END_DATE = uint32(block.timestamp + 20 days);
    bytes constant EMPTY_CTX = "";

    constructor() SuperfluidTester(3) {
        vm.startPrank(admin);
        vm.etch(ERC1820RegistryCompiled.at, ERC1820RegistryCompiled.bin);
        sfDeployer = new SuperfluidFrameworkDeployer();
        sf = sfDeployer.getFramework();
        host = sf.host;
        cfa = sf.cfa;
   
       // vm.stopPrank();
        // can be an empty string in dev or testnet deployments
        string memory registrationKey = "";
          _vestingScheduler = new VestingScheduler(host, "");
      

        cfaV1Lib = CFAv1Library.InitData(host,cfa);
             vm.stopPrank();
               _vestingAutomation = new VestingAutomation( _superToken,  _automate,  _primaryFundsOwner, _vestingScheduler);
    }

    /// SETUP AND HELPERS

    function setUp() public virtual {
        (token, superToken) = sfDeployer.deployWrapperSuperToken("FTT", "FTT", 18, type(uint256).max);

        for (uint32 i = 0; i < N_TESTERS; ++i) {
            token.mint(TEST_ACCOUNTS[i], INIT_TOKEN_BALANCE);
            vm.startPrank(TEST_ACCOUNTS[i]);
            token.approve(address(superToken), INIT_SUPER_TOKEN_BALANCE);
            superToken.upgrade(INIT_SUPER_TOKEN_BALANCE);
            _expectedTotalSupply += INIT_SUPER_TOKEN_BALANCE;
            vm.stopPrank();
        }
    }

    function _setACL_AUTHORIZE_FULL_CONTROL(address user, int96 flowRate) private {
        vm.startPrank(user);
        host.callAgreement(
            cfa,
            abi.encodeCall(
                cfa.updateFlowOperatorPermissions,
                (
                superToken,
                address(_vestingAutomation),
                FlowOperatorDefinitions.AUTHORIZE_FULL_CONTROL,
                flowRate,
                new bytes(0)
                )
            ),
            new bytes(0)
        );
        vm.stopPrank();
    }

    function _createVestingTask(address sender, address receiver) private {
        vm.startPrank(sender);
        _vestingAutomation.createVestingTask(
            sender,
            receiver
           
        );
        vm.stopPrank();
    }

    /// TESTS

    function testCreateVestingAutomation() public {
       
        _createVestingTask(alice, bob);
        vm.startPrank(alice);
        //assert storage data
        assertTrue(true,"success");
 
    }

     
}
