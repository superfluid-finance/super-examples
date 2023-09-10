// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IConstantFlowAgreementV1 } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";
import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import { ISuperfluid } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { IResolver } from "./interfaces/IResolver.sol";

/**
 * @title A simple Gelato resolver which utilizes Superfluid's ACL feature to close a single stream.
 * @author Superfluid
 * @dev This only works for a single token and one stream at a time.
 */
contract SimpleACLCloseResolver is IResolver, Ownable {
    //STATE VARS
    /// @notice address of deployed CFA contract
    IConstantFlowAgreementV1 public cfa;
    /// @notice super token to be used
    ISuperToken public superToken;

    /// @notice endTime - to be set as the timestamp that the gelato network should close the stream
    uint256 public endTime;
    /// @notice sender of the stream to be automated
    address public flowSender;
    /// @notice receiver of the stream to be automated
    address public flowReceiver;

    /// EVENTS
    /// @dev custom error to run when end time is invalid (i.e. prior to current block.timestamp value)
    error InvalidEndTime();
    /// @dev  custom error to run when flow receiver is invalid (i.e. if it's the zero address or = sender address)
    error InvalidFlowReceiver();
    /// @dev custom error to run when flow sender is invalid (i.e. if it's the zero address or = receiver address)
    error InvalidFlowSender();

    /// @dev emitted when flow end time is updated
    /// @param currentOwner - the current owner of this contract... by default this will also be the executor of the update
    /// @param endTime - the new endtime
    event EndTimeUpdated(address indexed currentOwner, uint256 endTime);

    /// @dev emitted when receiver of flow is updated
    /// @param currentOwner - the current owner of this contract... by default this will also be the executor of the update
    /// @param flowReceiver - the new receiver of the flow
    event FlowReceiverUpdated(
        address indexed currentOwner,
        address flowReceiver
    );

    /// @dev emitted when sender of flow is updated
    /// @param currentOwner - the current owner of this contract... by default this will also be the executor of the update
    /// @param flowSender - the new sender of the flow
    event FlowSenderUpdated(address indexed currentOwner, address flowSender);

    ///Simple ACL Resolver contract
    /// @notice this contract is a Gelato resolver which is designed to be called by a gelato operator to automatically close a stream at a defined future date
    /// params here are initialized in the constructor
    constructor(
        uint256 _endTime,
        IConstantFlowAgreementV1 _cfa,
        ISuperToken _superToken,
        address _flowSender,
        address _flowReceiver
    ) {
        if (_endTime < block.timestamp) revert InvalidEndTime();
        endTime = _endTime;
        cfa = _cfa;
        superToken = _superToken;
        flowSender = _flowSender;
        flowReceiver = _flowReceiver;
    }

    /// EXTERNAL FUNCTIONS
    ///@notice allows the owner to change the endTime of the stream
    ///@param _endTime - the new endTime of the stream
    function updateEndTime(uint256 _endTime) external onlyOwner {
        if (_endTime < block.timestamp) revert InvalidEndTime();
        endTime = _endTime;

        emit EndTimeUpdated(msg.sender, _endTime);
    }

    ///@notice allows the owner to update the receiver of the stream
    ///@param _flowReceiver the new receiver of the stream
    function updateFlowReceiver(address _flowReceiver) external onlyOwner {
        if (_flowReceiver == flowSender || _flowReceiver == address(0))
            revert InvalidFlowReceiver();
        flowReceiver = _flowReceiver;

        emit FlowReceiverUpdated(msg.sender, _flowReceiver);
    }

    ///@notice allows the owner to update the sender of the stream
    ///@param _flowSender the new sender of the stream
    function updateFlowSender(address _flowSender) external onlyOwner {
        if (_flowSender == flowReceiver || _flowSender == address(0))
            revert InvalidFlowSender();
        flowSender = _flowSender;

        emit FlowSenderUpdated(msg.sender, _flowSender);
    }

    ///@notice the checker() function is called by gelato ops periodically
    /// returns a boolean canExec that is true if it can be executed
    /// returns a bytes value containing calldata to run if canExec = true
    function checker()
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        // timestamp == 0 means the flow doesn't exist so it won't try to execute
        (uint256 timestamp, , , ) = cfa.getFlow(
            superToken,
            flowSender,
            flowReceiver
        );

        // NOTE: this can be modified to execute based on different conditions
        // e.g. supertoken balance reaches a specific amount
        canExec = block.timestamp >= endTime && timestamp != 0;

        bytes memory callData = abi.encodeCall(
            cfa.deleteFlowByOperator,
            (superToken, flowSender, flowReceiver, new bytes(0))
        );

        // NOTE: this can be modified to execute pretty much any function
        // given the permissions
        // e.g. other host contract functions, supertoken upgrades/downgrades
        execPayload = abi.encodeCall(
            ISuperfluid(superToken.getHost()).callAgreement,
            (IConstantFlowAgreementV1(cfa), callData, "0x")
        );
    }
}
