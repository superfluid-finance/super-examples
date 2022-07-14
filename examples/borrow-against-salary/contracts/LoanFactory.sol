// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ISuperfluid, ISuperToken, ISuperApp, ISuperAgreement, SuperAppDefinitions} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import {EmploymentLoan} from "./EmploymentLoan.sol";

contract LoanFactory {
    uint256 loanId = 0;
    mapping(uint256 => EmploymentLoan) public idToLoan;
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

    function getLoanAddressByID(uint256 _id) public view returns (EmploymentLoan) {
        return idToLoan[_id];
    }

    function getLoanByOwner(address _owner) public view returns (uint256) {
        return employmentLoanOwners[_owner];
    }
}
