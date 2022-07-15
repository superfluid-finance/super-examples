// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ISuperfluid, ISuperToken, ISuperApp, ISuperAgreement, SuperAppDefinitions} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import {CFAv1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";

import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import {SuperAppBase} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";

contract EmploymentLoan is SuperAppBase {
    using CFAv1Library for CFAv1Library.InitData;
    CFAv1Library.InitData public cfaV1;

    bytes32 constant CFA_ID =
        keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");

    uint256 public loanStartTime;
    int256 public borrowAmount;
    int8 public interestRate;
    int256 public paybackMonths;
    address public employer;
    address public borrower;
    address public lender;
    ISuperfluid public host;
    ISuperToken public borrowToken;

    bool public loanOpen;

    constructor(
        int256 _borrowAmount,
        int8 _interestRate, //annual interest rate, in whole number - i.e. 8% would be passed as 8
        int256 _paybackMonths,
        address _employer,
        address _borrower,
        ISuperToken _borrowToken,
        ISuperfluid _host
    ) {
        IConstantFlowAgreementV1 cfa = IConstantFlowAgreementV1(
            address(_host.getAgreementClass(CFA_ID))
        );

        borrowAmount = _borrowAmount;
        interestRate = _interestRate;
        paybackMonths = _paybackMonths;
        employer = _employer;
        borrower = _borrower;
        borrowToken = _borrowToken;
        host = _host;
        loanOpen = false;

        cfaV1 = CFAv1Library.InitData(_host, cfa);

        uint256 configWord = SuperAppDefinitions.APP_LEVEL_FINAL |
            SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;

        _host.registerApp(configWord);
    }

    function getPaymentFlowRate() public view returns (int96 paymentFlowRate) {
        return (
            int96(
                ((borrowAmount + ((borrowAmount * int256(interestRate)) / int256(100))) /
                    paybackMonths) / ((365 / 12) * 86400)
            )
        );
    }

    function getTotalAmountRemaining() public view returns (uint256) {
        //if there is no time left on loan, return zero
        int256 secondsLeft = (paybackMonths * int256((365 * 86400) / 12)) -
            int256(block.timestamp - loanStartTime);
        if (secondsLeft <= 0) {
            return 0;
        }
        //if an amount is left, return the total amount to be paid
        else {
            return uint256(secondsLeft) * uint256(int256(getPaymentFlowRate()));
        }
    }

    //lender can use this function to send funds to the borrower and start the loan
    function lend() external {
        (, int96 employerFlowRate, , ) = cfaV1.cfa.getFlow(borrowToken, employer, address(this));

        require(employerFlowRate >= getPaymentFlowRate());

        //lender must approve contract before running next line
        borrowToken.transferFrom(msg.sender, borrower, uint256(borrowAmount));
        //want to make sure that tokens are sent successfully first before setting lender to msg.sender
        int96 netFlowRate = cfaV1.cfa.getNetFlow(borrowToken, address(this));
        (, int96 outFlowRate, , ) = cfaV1.cfa.getFlow(borrowToken, address(this), borrower);

        //update flow to borrower (aka the employee)
        cfaV1.updateFlow(
            borrower,
            borrowToken,
            ((netFlowRate - outFlowRate) * -1) - getPaymentFlowRate()
        );
        //create flow to lender
        cfaV1.createFlow(msg.sender, borrowToken, getPaymentFlowRate());

        loanOpen = true;
        lender = msg.sender;
        loanStartTime = block.timestamp;
    }

    ///If a new stream is opened, or an existing one is opened
    //1) get expected payment flowRte, current netflowRate, etc.
    //2) check how much the employer is sending - if they're not sending enough, revert

    function _updateOutFlowCreate(
        bytes calldata ctx,
        int96 paymentFlowRate,
        int96 inFlowRate
    ) private returns (bytes memory newCtx) {
        newCtx = ctx;
        //get the current sender of the flow
        address sender = host.decodeCtx(ctx).msgSender;
        //this will revert and no outflow or inflow will be created if the sender of the flow is not the emploer
        require(sender == employer, "sender of flow must be the employer");
        // @dev If there is no existing outflow, then create new flow to equal inflow
        // sender must also be the employer
        //create flow to employee
        //if loan is still open, we need to make sure that the right amount of funds are sent to the borrower & lender
        if (loanOpen == true) {
            newCtx = cfaV1.createFlowWithCtx(
                newCtx,
                borrower,
                borrowToken,
                inFlowRate - paymentFlowRate
            );
            newCtx = cfaV1.createFlowWithCtx(newCtx, lender, borrowToken, paymentFlowRate);
        } else {
            //if loanOpen is not true, we need to send the borrower the full inflow
            newCtx = cfaV1.createFlowWithCtx(newCtx, borrower, borrowToken, inFlowRate);
        }
    }

    function _updateOutFlowUpdate(
        bytes calldata ctx,
        int96 paymentFlowRate,
        int96 outFlowRateLender,
        int96 inFlowRate
    ) private returns (bytes memory newCtx) {
        newCtx = ctx;
        //this will get us the amount of money that should be redirected to the lender out of the inflow, denominated in borrow token

        (, int96 borrowerInFlow, , ) = cfaV1.cfa.getFlow(borrowToken, address(this), borrower);
        //if the amount being sent is enough to cover loan
        if ((inFlowRate - paymentFlowRate) > 0) {
            if (outFlowRateLender > 0) {
                if (borrowerInFlow > 0) {
                    newCtx = cfaV1.updateFlowWithCtx(
                        newCtx,
                        borrower,
                        borrowToken,
                        inFlowRate - paymentFlowRate
                    );
                } else {
                    newCtx = cfaV1.createFlowWithCtx(
                        newCtx,
                        borrower,
                        borrowToken,
                        inFlowRate - paymentFlowRate
                    );
                }
                newCtx = cfaV1.updateFlowWithCtx(newCtx, lender, borrowToken, paymentFlowRate);
            } else {
                newCtx = cfaV1.updateFlowWithCtx(newCtx, borrower, borrowToken, inFlowRate);
            }
        } else if ((inFlowRate - paymentFlowRate < 0) && inFlowRate > 0) {
            //if inFlowRate is less than the required amount to pay interest, but there's still a flow, we'll stream it all to the lender
            if (outFlowRateLender > 0) {
                newCtx = cfaV1.deleteFlowWithCtx(newCtx, address(this), borrower, borrowToken);
                newCtx = cfaV1.updateFlowWithCtx(newCtx, lender, borrowToken, inFlowRate);
            } else {
                //in this case, there is no lender outFlowRate..so we need to just update the outflow to borrower
                newCtx = cfaV1.updateFlowWithCtx(newCtx, borrower, borrowToken, inFlowRate);
            }
        } else {
            //in this case, there is no inFlowRate....
            newCtx = cfaV1.deleteFlowWithCtx(newCtx, address(this), borrower, borrowToken);
            if (outFlowRateLender > 0) {
                newCtx = cfaV1.deleteFlowWithCtx(newCtx, address(this), lender, borrowToken);
            }
        }
    }

    function _updateOutFlowDelete(bytes calldata ctx, int96 outFlowRateLender)
        private
        returns (bytes memory newCtx)
    {
        newCtx = ctx;
        //delete flow to lender in borrow token if they are currently receiving a flow
        if (outFlowRateLender > 0) {
            newCtx = cfaV1.deleteFlowWithCtx(newCtx, address(this), lender, borrowToken);
        }
        //delete flow to borrower in borrow token
        newCtx = cfaV1.deleteFlowWithCtx(newCtx, address(this), borrower, borrowToken);
    }

    function _updateOutflow(bytes calldata ctx) private returns (bytes memory newCtx) {
        newCtx = ctx;
        //this will get us the amount of money that should be redirected to the lender out of the inflow, denominated in borrow token
        int96 paymentFlowRate = getPaymentFlowRate();
        // @dev This will give me the new flowRate, as it is called in after callbacks
        int96 netFlowRate = cfaV1.cfa.getNetFlow(borrowToken, address(this));

        //current amount being sent to lender
        (, int96 outFlowRateLender, , ) = cfaV1.cfa.getFlow(borrowToken, address(this), lender);
        //current amount being sent to borrower
        (, int96 outFlowRateBorrower, , ) = cfaV1.cfa.getFlow(borrowToken, address(this), borrower);
        //total outflow rate in borrow token - only 2
        int96 outFlowRate = outFlowRateLender + outFlowRateBorrower;
        //total inflow rate in borrow token
        int96 inFlowRate = netFlowRate + outFlowRate;

        if (inFlowRate < 0) {
            inFlowRate = inFlowRate * -1; // Fixes issue when inFlowRate is negative
        }

        // @dev If inFlow === 0 && outflowRate > 0, then delete existing flows.
        if (inFlowRate == int96(0)) {
            newCtx = _updateOutFlowDelete(ctx, outFlowRateLender);
        }
        //if flow exists, update the flow according to various params
        else if (outFlowRate != int96(0)) {
            newCtx = _updateOutFlowUpdate(ctx, paymentFlowRate, outFlowRateLender, inFlowRate);
        }
        //no flow exists into the contract in borrow token
        else {
            newCtx = _updateOutFlowCreate(ctx, paymentFlowRate, inFlowRate);
            // @dev If there is no existing outflow, then create new flow to equal inflow
        }
    }

    //function to close a loan that is already completed
    function closeCompletedLoan() external {
        require(msg.sender == lender || getTotalAmountRemaining() <= 0);

        (, int96 currentLenderFlowRate, , ) = cfaV1.cfa.getFlow(borrowToken, address(this), lender);
        cfaV1.deleteFlow(address(this), lender, borrowToken);

        (, int96 currentFlowRate, , ) = cfaV1.cfa.getFlow(borrowToken, address(this), borrower);
        cfaV1.updateFlow(borrower, borrowToken, currentFlowRate + currentLenderFlowRate);
        loanOpen = false;
    }

    //allows lender or borrower to close a loan
    //if the loan is paid off, or if the loan is closed by the lender, pass 0
    //if the loan is not yet paid off, pass in the required amount to close loan
    function closeOpenLoan(uint256 amountForPayoff) external {
        (, int96 currentLenderFlowRate, , ) = cfaV1.cfa.getFlow(borrowToken, address(this), lender);
        (, int96 currentFlowRate, , ) = cfaV1.cfa.getFlow(borrowToken, address(this), borrower);

        if (msg.sender == lender) {
            cfaV1.deleteFlow(address(this), lender, borrowToken);
            cfaV1.updateFlow(borrower, borrowToken, currentFlowRate + currentLenderFlowRate);
            loanOpen = false;
        } else {
            if (getTotalAmountRemaining() > 0) {
                require(amountForPayoff >= (getTotalAmountRemaining()), "insuf funds");
                borrowToken.transferFrom(msg.sender, lender, amountForPayoff);

                cfaV1.deleteFlow(address(this), lender, borrowToken);

                cfaV1.updateFlow(borrower, borrowToken, currentFlowRate + currentLenderFlowRate);
                loanOpen = false;
            } else {
                cfaV1.deleteFlow(address(this), lender, borrowToken);
                cfaV1.updateFlow(borrower, borrowToken, currentFlowRate + currentLenderFlowRate);
                loanOpen = false;
            }
        }
    }

    function afterAgreementCreated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32, // _agreementId,
        bytes calldata, /*_agreementData*/
        bytes calldata, // _cbdata,
        bytes calldata ctx
    ) external override onlyExpected(_superToken, _agreementClass) returns (bytes memory newCtx) {
        newCtx = _updateOutflow(ctx);
    }

    function afterAgreementUpdated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32, // _agreementId,
        bytes calldata, /*_agreementData*/
        bytes calldata, // _cbdata,
        bytes calldata ctx
    )
        external
        override
        onlyExpected(_superToken, _agreementClass)
        onlyHost
        returns (bytes memory newCtx)
    {
        newCtx = _updateOutflow(ctx);
    }

    function afterAgreementTerminated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32, // _agreementId,
        bytes calldata, /*_agreementData*/
        bytes calldata, // _cbdata,
        bytes calldata ctx
    ) external override onlyHost returns (bytes memory newCtx) {
        if (!_isCFAv1(_agreementClass) || !_isSameToken(_superToken)) {
            return ctx;
        }
        return _updateOutflow(ctx);
    }

    function _isCFAv1(address agreementClass) private view returns (bool) {
        return ISuperAgreement(agreementClass).agreementType() == CFA_ID;
    }

    function _isSameToken(ISuperToken superToken) private view returns (bool) {
        return address(superToken) == address(borrowToken);
    }

    modifier onlyHost() {
        require(msg.sender == address(cfaV1.host), "Only host can call callback");
        _;
    }

    modifier onlyExpected(ISuperToken superToken, address agreementClass) {
        require(_isSameToken(superToken), "RedirectAll: not accepted token");
        require(_isCFAv1(agreementClass), "RedirectAll: only CFAv1 supported");
        _;
    }
}
