// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ISuperfluid, ISuperToken, ISuperApp, ISuperAgreement, SuperAppDefinitions} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import {EmploymentLoan} from "./EmploymentLoan.sol";

contract LoanFactory {
    /// @notice counter which is iterated +1 for each new loan created.
    /// @dev Note that the value begins at 0 here, but the first one will start at one.
    uint256 public loanId;

    /// @notice mapping of loanId to the loan contract
    mapping(uint256 => EmploymentLoan) public idToLoan;

    /// @notice mapping of loan owner (i.e. the msg.sender on the call) to the loan Id
    mapping(address => uint256) public employmentLoanOwners;

    /// @notice Creates new loan contract.
    /// @param _borrowAmount Amount to borrow.
    /// @param _interestRate Interest rate.
    /// @param _paybackMonths Number of months for repayment.
    /// @param _employer Employer address.
    /// @param _borrower Borrower address.
    /// @param _borrowToken Token to borrow.
    /// @param _host Superfluid host.
    /// @return Loan ID.
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

    /// @notice Query loan address from loan id.
    /// @param _id Loan ID.
    /// @return Loan Address.
    function getLoanAddressByID(uint _id) public view returns (EmploymentLoan) {
        return idToLoan[_id];
    }

    /// @notice Query loan address from owner.
    /// @param _owner Employee.
    /// @return Loan Address.
    function getLoanByOwner(address _owner) public view returns (uint) {
        return employmentLoanOwners[_owner];
    }
}
