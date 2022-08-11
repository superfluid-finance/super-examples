//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.14;

import "hardhat/console.sol";

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ISuperfluid, ISuperToken, ISuperApp} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import {ISuperfluidToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluidToken.sol";

import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import {CFAv1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";

contract MoneyRouter {
    ///owner of contract
    address public owner;

    ///initialization of CFA lib
    using CFAv1Library for CFAv1Library.InitData;
    CFAv1Library.InitData public cfaV1; //initialize cfaV1 variable

    ///mapping list of whitelisted accounts
    mapping(address => bool) public accountList;

    ///constructor requires the address of the superfluid host, which can be found for each network at https://console.superfluid.finance/protocol
    ///owner is the initial owner of the contract
    constructor(ISuperfluid host, address _owner) {
        assert(address(host) != address(0));
        console.log("Deploying a Money Router with owner:", owner);
        owner = _owner;

        //initialize InitData struct, and set equal to cfaV1
        cfaV1 = CFAv1Library.InitData(
            host,
            //here, we are deriving the address of the CFA using the host contract
            IConstantFlowAgreementV1(
                address(
                    host.getAgreementClass(
                        keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1")
                    )
                )
            )
        );
    }

    ///whitelist an account who is able to call functions on this contract
    function whitelistAccount(address _account) external {
        require(msg.sender == owner, "only owner can whitelist accounts");
        accountList[_account] = true;
    }

    ///remove an account from whitelist
    function removeAccount(address _account) external {
        require(msg.sender == owner, "only owner can remove accounts");
        accountList[_account] = false;
    }

    ///transfer ownership over the contract
    function changeOwner(address _newOwner) external {
        require(msg.sender == owner, "only owner can change ownership");
        owner = _newOwner;
    }

    ///send a lump sum of super tokens into the contract. NOTE: this requires a super token ERC20 approval step first
    function sendLumpSumToContract(ISuperToken token, uint256 amount) external {
        require(msg.sender == owner || accountList[msg.sender] == true, "must be authorized");
        token.transferFrom(msg.sender, address(this), amount);
    }

    ///create a stream into the contract. NOTE: this requires the contract to be a flowOperator for the caller
    function createFlowIntoContract(ISuperfluidToken token, int96 flowRate) external {
        require(msg.sender == owner || accountList[msg.sender] == true, "must be authorized");

        cfaV1.createFlowByOperator(msg.sender, address(this), token, flowRate);
    }

    ///update an existing stream being sent into the contract by msg.sender. NOTE: this requires the contract to be a flowOperator for the caller
    function updateFlowIntoContract(ISuperfluidToken token, int96 newFlowRate) external {
        require(msg.sender == owner || accountList[msg.sender] == true, "must be authorized");

        cfaV1.updateFlowByOperator(msg.sender, address(this), token, newFlowRate);
    }

    ///delete a stream that the msg.sender has open into the contract
    function deleteFlowIntoContract(ISuperfluidToken token) external {
        require(msg.sender == owner || accountList[msg.sender] == true, "must be authorized");

        cfaV1.deleteFlow(msg.sender, address(this), token);
    }

    ///take funds from the contract
    function withdrawFunds(ISuperToken token, uint256 amount) external {
        require(msg.sender == owner || accountList[msg.sender] == true, "must be authorized");
        token.transfer(msg.sender, amount);
    }

    ///create flow from contract to specified address
    function createFlowFromContract(
        ISuperfluidToken token,
        address receiver,
        int96 flowRate
    ) external {
        require(msg.sender == owner || accountList[msg.sender] == true, "must be authorized");
        cfaV1.createFlow(receiver, token, flowRate);
    }

    ///update one of the contract's existing outflows
    function updateFlowFromContract(
        ISuperfluidToken token,
        address receiver,
        int96 newFlowRate
    ) external {
        require(msg.sender == owner || accountList[msg.sender] == true, "must be authorized");
        cfaV1.updateFlow(receiver, token, newFlowRate);
    }

    ///delete an existing stream that the contract is sending
    function deleteFlowFromContract(ISuperfluidToken token, address receiver) external {
        require(msg.sender == owner || accountList[msg.sender] == true, "must be authorized");
        cfaV1.deleteFlow(address(this), receiver, token);
    }
}
