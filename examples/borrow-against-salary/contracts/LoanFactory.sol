// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ISuperfluid, ISuperToken, ISuperApp, ISuperAgreement, SuperAppDefinitions} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import {EmploymentLoan} from "./EmploymentLoan.sol";

contract LoanFactory {
    ///counter which is iterated +1 for each new loan created. Note that the value begins at 0 here, but the first one will start at one
    uint256 loanId = 0;

    ///mapping of loanId to the loan contract
    mapping(uint256 => EmploymentLoan) public idToLoan;
    ///mapping of loan owner (i.e. the msg.sender on the call) to the loan Id
    mapping(address => uint256) public employmentLoanOwners;

    function createNewLoan(
        int256 _borrowAmount,
        int8 _interestRate,
        int8 _paybackMonths,
        address _employer,
        address _borrower,
        ISuperToken _borrowToken,
        ISuperfluid _host
    ) external returns (uint256) {
        EmploymentLoan newLoan = new EmploymentLoan(
            _borrowAmount,
            _interestRate,
            _paybackMonths,
            _employer,
            _borrower,
            _borrowToken,
            _host
        );

        loanId++;

        idToLoan[loanId] = newLoan;
        employmentLoanOwners[msg.sender] = loanId;

        return loanId;
    }

    //get loan address by Id
    function getLoanAddressByID(uint256 _id) public view returns (EmploymentLoan) {
        return idToLoan[_id];
    }

    //get loan address by owner
    function getLoanByOwner(address _owner) public view returns (uint256) {
        return employmentLoanOwners[_owner];
    }
}
