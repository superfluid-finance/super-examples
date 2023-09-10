// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "hardhat/console.sol";

import {AutomateTaskCreator} from "./gelato/AutomateTaskCreator.sol";
import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import "./gelato/Types.sol";
import {IVestingScheduler} from "./interface/IVestingScheduler.sol";
import {VestingScheduler} from "./VestingScheduler.sol";

contract VestingAutomation is AutomateTaskCreator {
    /// @dev The SuperToken to be used for vesting
    ISuperToken vestingToken;
    /// @dev The VestingScheduler contract
    VestingScheduler public vestingScheduler;

    address public primaryFundsOwner;

    /// @dev struct for 'start vesting' tasks
    /// @param token The SuperToken to be used for vesting
    /// @param sender The sender i.e. the address sending the tokens
    /// @param receiver The receiver i.e. the address receiving the vested tokens
    /// @param startDate The date when the vesting starts
    /// @param timeScheduled The time when the task was scheduled
    struct VestingStartTask {
        ISuperToken token;
        address sender;
        address receiver;
        uint256 startDate;
        uint256 timeScheduled;
    }

    /// @dev struct for 'end vesting' tasks
    /// @param token The SuperToken to be used for vesting
    /// @param sender The sender i.e. the address sending the tokens
    /// @param receiver The receiver i.e. the address receiving the vested tokens
    /// @param endDate The date when the vesting ends
    /// @param timeScheduled The time when the task was scheduled
    struct VestingEndTask {
        ISuperToken token;
        address sender;
        address receiver;
        uint256 endDate;
        uint256 timeScheduled;
    }

    ///@dev mapping of start taskID to 'start vesting' tasks
    mapping(bytes32 => VestingStartTask) public vestingStartTasks;
    ///@dev mapping of end taskID to 'end vesting' tasks
    mapping(bytes32 => VestingEndTask) public vestingEndTasks;

    ///@dev mapping of new funds owners
    ///this is needed because the fundsOwner variable in the gelato AutomateTaskCreator contract is immutable
    ///we want to allow the controller of the contract to add a secondary address in case a private key is lost or exposed
    ///if we only allow the primary funds owner to to withdraw funds, we would be locked out of the contract
    mapping(address => bool) public fundsOwners;

    ///@dev constructor
    ///@param _vestingSuperToken The SuperToken to be used for vesting
    ///@param _automate The address of the AutomateTaskCreator contract (from Gelato Core)
    ///@param _primaryFundsOwner The address of the contract owner/address that will pay for the tasks by sending tokens to this contract
    ///@param _vestingScheduler The address of the VestingScheduler contract
    constructor(
        ISuperToken _vestingSuperToken,
        address _automate,
        address _primaryFundsOwner,
        VestingScheduler _vestingScheduler
    ) AutomateTaskCreator(_automate, _primaryFundsOwner) {
        primaryFundsOwner = _primaryFundsOwner;
        fundsOwners[_primaryFundsOwner] = true;
        vestingScheduler = _vestingScheduler;
        vestingToken = _vestingSuperToken;
    }

    ///@dev call this function to set up a vesting task
    ///@param sender The sender i.e. the address sending the tokens
    ///@param receiver The receiver i.e. the address receiving the vested tokens
    ///@return startTaskId The taskID of the start vesting task
    ///@return endTaskId The taskID of the end vesting task
    function createVestingTask(
        address sender,
        address receiver
    ) external returns (bytes32 startTaskId, bytes32 endTaskId) {
        require(msg.sender == fundsOwner, "Only funds owner can create tasks");
        //use sender, receiver, and vestingToken to get the vesting schedule programmatically from VestingScheduler contract
        IVestingScheduler.VestingSchedule memory vSchedule = vestingScheduler.getVestingSchedule(
            address(vestingToken),
            sender,
            receiver
        );

        uint32 _cliffAndFlowDate = vSchedule.cliffAndFlowDate;
        uint32 _endDate = vSchedule.endDate;

        //create the start + end vesting tasks in the same transaction
        startTaskId = _createVestingStartTask(sender, receiver, _cliffAndFlowDate);
        endTaskId = _createEndVestingTask(sender, receiver, _endDate);

        return (startTaskId, endTaskId);
    }

    ///@dev this function will create the start vesting task - i.e. executeCliffAndFlow
    ///@param sender The sender i.e. the address sending the tokens
    ///@param receiver The receiver i.e. the address receiving the vested tokens
    ///@param startDate The date when the vesting starts
    ///@return startTaskId The taskID of the start vesting task
    function _createVestingStartTask(
        address sender,
        address receiver,
        uint256 startDate
    ) internal returns (bytes32 startTaskId) {
        //note that the '100' value is only a placeholder
        //this is technically the 'interval' at which the task will be executed
        //but because we are using the SINGLE_EXEC module, the task will only be executed once
        bytes memory startTime = abi.encode(uint128(startDate), 100);

        bytes memory execData = abi.encodeWithSelector(
            this.executeStartVesting.selector,
            sender,
            receiver
        );

        ModuleData memory moduleData = ModuleData({modules: new Module[](2), args: new bytes[](2)});
        moduleData.modules[0] = Module.TIME;
        moduleData.modules[1] = Module.SINGLE_EXEC;

        moduleData.args[0] = startTime;
        moduleData.args[1] = _singleExecModuleArg();

        //note that ETH here is a placeholder for the native asset on any network you're using
        startTaskId = _createTask(address(this), execData, moduleData, ETH);

        //store the start task in the mapping
        vestingStartTasks[startTaskId] = VestingStartTask({
            token: vestingToken,
            sender: sender,
            receiver: receiver,
            startDate: startDate,
            timeScheduled: block.timestamp
        });

        return startTaskId;
    }

    ///@dev this function will create the delete vesting task - i.e. executeEndVesting
    ///@param sender The sender i.e. the address sending the tokens
    ///@param receiver The receiver i.e. the address receiving the vested tokens
    ///@param endDate The date when the vesting ends
    ///@return endTaskId The taskID of the end vesting task
    function _createEndVestingTask(
        address sender,
        address receiver,
        uint256 endDate
    ) internal returns (bytes32 endTaskId) {
        bytes memory endTime = abi.encode(uint128(endDate), 100);

        bytes memory execData = abi.encodeWithSelector(
            this.executeStartVesting.selector,
            sender,
            receiver
        );

        ModuleData memory moduleData = ModuleData({modules: new Module[](2), args: new bytes[](2)});
        moduleData.modules[0] = Module.TIME;
        moduleData.modules[1] = Module.SINGLE_EXEC;

        moduleData.args[0] = endTime;
        moduleData.args[1] = _singleExecModuleArg();

        //note that ETH here is a placeholder for the native asset on any network you're using
        endTaskId = _createTask(address(this), execData, moduleData, ETH);

        //store the end task in the mapping
        vestingEndTasks[endTaskId] = VestingEndTask({
            token: vestingToken,
            sender: sender,
            receiver: receiver,
            endDate: endDate,
            timeScheduled: block.timestamp
        });

        return endTaskId;
    }

    ///@dev this function will be called by the OpsReady contract to execute the start vesting task on the vesting cliff date
    ///@param sender The sender i.e. the address sending the tokens
    ///@param receiver The receiver i.e. the address receiving the vested tokens
    function executeStartVesting(address sender, address receiver) external {
        //handle fee logic
        (uint256 fee, address feeToken) = _getFeeDetails();
        _transfer(fee, feeToken);

        vestingScheduler.executeCliffAndFlow(vestingToken, sender, receiver);
    }

    ///@dev this function will be called by the OpsReady contract to execute the end vesting task on the vesting end date
    ///@param sender The sender i.e. the address sending the tokens
    ///@param receiver The receiver i.e. the address receiving the vested tokens
    function executeStopVesting(address sender, address receiver) external {
        //handle fee logic
        (uint256 fee, address feeToken) = _getFeeDetails();
        _transfer(fee, feeToken);

        vestingScheduler.executeEndVesting(vestingToken, sender, receiver);
    }

    ///@dev this function will receive native asset for gas payments
    ///note that this contract must have enough of the native asset tokens to pay for the gas fees of executing vesting tasks
    receive() external payable {
        console.log("----- receive:", msg.value);
    }

    ///@dev this function will allow the current contract owner to change ownership
    ///@param newFundsOwner The new owner of the contract
    function addFundsOwner(address newFundsOwner) external {
        // only the funds owner can execute this fn
        require(fundsOwners[msg.sender] == true, "NOT_ALLOWED");
        fundsOwners[newFundsOwner] = true;
    }

    ///@dev this function will allow the current contract owner to change ownership
    ///@param removedFundsOwner The new owner of the contract
    function removeFundsOwner(address removedFundsOwner) external {
        // only a funds owner can execute this fn
        require(removedFundsOwner != primaryFundsOwner, "CANNOT_REMOVE_PRIMARY_FUNDS_OWNER");
        require(fundsOwners[msg.sender] == true, "NOT_ALLOWED");
        fundsOwners[removedFundsOwner] = false;
    }

    ///@dev this function will allow the current contract owner to withdraw funds (i.e. the native asset within the contract)
    function withdraw() external returns (bool) {
        // only the funds owner can withdraw funds - note that fundsOwner is defined in the AutomateTaskCreator contract
        require(fundsOwners[msg.sender] == true, "NOT_ALLOWED");

        (bool result, ) = payable(msg.sender).call{value: address(this).balance}("");
        return result;
    }
}
