//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.14;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ISuperfluid, ISuperToken, ISuperApp} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISuperfluidToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluidToken.sol";
import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import {CFAv1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";

error Unauthorized();

contract MoneyRouter {
    // ---------------------------------------------------------------------------------------------
    // STATE VARIABLES

    /// @notice Owner.
    address public owner;

    /// @notice CFA Library.
    using CFAv1Library for CFAv1Library.InitData;
    CFAv1Library.InitData public cfaV1;

    /// @notice Allow list.
    mapping(address => bool) public accountList;

    constructor(ISuperfluid host, address _owner) {
        assert(address(host) != address(0));
        owner = _owner;

        // Initialize CFA Library
        cfaV1 = CFAv1Library.InitData(
            host,
            IConstantFlowAgreementV1(
                address(
                    host.getAgreementClass(
                        keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1")
                    )
                )
            )
        );
    }

    /// @notice Add account to allow list.
    /// @param _account Account to allow.
    function allowAccount(address _account) external {
        if (msg.sender != owner) revert Unauthorized();

        accountList[_account] = true;
    }

    /// @notice Removes account from allow list.
    /// @param _account Account to disallow.
    function removeAccount(address _account) external {
        if (msg.sender != owner) revert Unauthorized();

        accountList[_account] = false;
    }

    /// @notice Transfer ownership.
    /// @param _newOwner New owner account.
    function changeOwner(address _newOwner) external {
        if (msg.sender != owner) revert Unauthorized();

        owner = _newOwner;
    }

    /// @notice Send a lump sum of super tokens into the contract.
    /// @dev This requires a super token ERC20 approval.
    /// @param token Super Token to transfer.
    /// @param amount Amount to transfer.
    function sendLumpSumToContract(ISuperToken token, uint256 amount) external {
        if (!accountList[msg.sender] && msg.sender != owner) revert Unauthorized();

        token.transferFrom(msg.sender, address(this), amount);
    }

    /// @notice Create a stream into the contract.
    /// @dev This requires the contract to be a flowOperator for the msg sender.
    /// @param token Token to stream.
    /// @param flowRate Flow rate per second to stream.
    function createFlowIntoContract(ISuperfluidToken token, int96 flowRate) external {
        if (!accountList[msg.sender] && msg.sender != owner) revert Unauthorized();

        cfaV1.createFlowByOperator(msg.sender, address(this), token, flowRate);
    }

    /// @notice Update an existing stream being sent into the contract by msg sender.
    /// @dev This requires the contract to be a flowOperator for the msg sender.
    /// @param token Token to stream.
    /// @param flowRate Flow rate per second to stream.
    function updateFlowIntoContract(ISuperfluidToken token, int96 flowRate) external {
        if (!accountList[msg.sender] && msg.sender != owner) revert Unauthorized();

        cfaV1.updateFlowByOperator(msg.sender, address(this), token, flowRate);
    }

    /// @notice Delete a stream that the msg.sender has open into the contract.
    /// @param token Token to quit streaming.
    function deleteFlowIntoContract(ISuperfluidToken token) external {
        if (!accountList[msg.sender] && msg.sender != owner) revert Unauthorized();

        cfaV1.deleteFlow(msg.sender, address(this), token);
    }

    /// @notice Withdraw funds from the contract.
    /// @param token Token to withdraw.
    /// @param amount Amount to withdraw.
    function withdrawFunds(ISuperToken token, uint256 amount) external {
        if (!accountList[msg.sender] && msg.sender != owner) revert Unauthorized();

        token.transfer(msg.sender, amount);
    }

    /// @notice Create flow from contract to specified address.
    /// @param token Token to stream.
    /// @param receiver Receiver of stream.
    /// @param flowRate Flow rate per second to stream.
    function createFlowFromContract(
        ISuperfluidToken token,
        address receiver,
        int96 flowRate
    ) external {
        if (!accountList[msg.sender] && msg.sender != owner) revert Unauthorized();

        cfaV1.createFlow(receiver, token, flowRate);
    }

    /// @notice Update flow from contract to specified address.
    /// @param token Token to stream.
    /// @param receiver Receiver of stream.
    /// @param flowRate Flow rate per second to stream.
    function updateFlowFromContract(
        ISuperfluidToken token,
        address receiver,
        int96 flowRate
    ) external {
        if (!accountList[msg.sender] && msg.sender != owner) revert Unauthorized();

        cfaV1.updateFlow(receiver, token, flowRate);
    }

    /// @notice Delete flow from contract to specified address.
    /// @param token Token to stop streaming.
    /// @param receiver Receiver of stream.
    function deleteFlowFromContract(ISuperfluidToken token, address receiver) external {
        if (!accountList[msg.sender] && msg.sender != owner) revert Unauthorized();

        cfaV1.deleteFlow(address(this), receiver, token);
    }
}
