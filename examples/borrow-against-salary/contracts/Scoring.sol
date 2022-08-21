// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {EmploymentLoan} from "./EmploymentLoan.sol";

import {LoanFactory} from "./LoanFactory.sol";

contract Scoring {
    address public immutable factoryAddress;

    constructor (
        address _factoryAddress
    ) {
        factoryAddress = _factoryAddress;
    }

    function getScore(address _address) public view returns (int) {
        LoanFactory LF = LoanFactory(factoryAddress);
    
        int opened = 0;
        int total = 0;

        for (uint256 id = 1; id <= LF.loanId(); id++ ) {
            EmploymentLoan loan = LF.idToLoan(id);
            if (loan.borrower()  == _address) {
                total++;
                if (loan.loanOpen())
                    opened++; 
            }
        }

        if ( opened > 0 )
            return -1;

        return total;
    }
}

// TODO: Do more advanced scoring by analysing channel closures. (by third parties)