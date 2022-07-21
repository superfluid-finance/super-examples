// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ISuperfluid, ISuperToken, ISuperApp, ISuperAgreement, SuperAppDefinitions} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import {CFAv1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";

import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import {SuperAppBase} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";

contract EmploymentLoan is SuperAppBase {
    ///importing the CFAv1 Library to make working with streams easy
    using CFAv1Library for CFAv1Library.InitData;
    CFAv1Library.InitData public cfaV1;

    ///constant used for initialization of CFAv1 and for callback modifiers
    bytes32 constant CFA_ID =
        keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");

    ///the block.timestamp of the loan start time
    uint256 public loanStartTime;
    ///total amount that is being borrowed in the borrow token
    int256 public borrowAmount;
    ///interest rate, in whole number. I.e. 8% interest rate would be passed as '8'
    int8 public interestRate;
    ///number of months the loan will be paid back in. I.e. 2 years = '24'
    int256 public paybackMonths;
    ///address of employer - must be whitelisted for this example
    address public employer;
    ///address of borrower
    address public borrower;
    ///account lending to borrower
    address public lender;

    ///address of superfluid host contract. can be found at https://console.superfluid.finance/protocol
    ISuperfluid public host;
    ///token being borrowed. you can find super token addresses at https://console.superfluid.finance/super-tokens
    ISuperToken public borrowToken;

    ///boolean flag to track whether or not the loan is open
    bool public loanOpen;

    constructor(
        int256 _borrowAmount, ///amount to be borrowed
        int8 _interestRate, ///annual interest rate, in whole number - i.e. 8% would be passed as 8
        int256 _paybackMonths, ///total payback months
        address _employer, ///whitelisted employer address
        address _borrower, ///borrower address
        ISuperToken _borrowToken, ///super token to be used in borrowing
        ISuperfluid _host /// address of SF host
    ) {
        ///used in initialization of the CFA lib
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

        ///CFAv1 library initialization
        cfaV1 = CFAv1Library.InitData(_host, cfa);

        ///super app registration
        uint256 configWord = SuperAppDefinitions.APP_LEVEL_FINAL |
            SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;
        ///using host.registerApp because we are using testnet. If you would like to deploy to mainnet, this process will work differently. You'll need to use registerAppWithKey or registerAppByFactory
        ///learn more at: https://github.com/superfluid-finance/protocol-monorepo/wiki/Super-App-White-listing-Guide
        _host.registerApp(configWord);
    }

    ///used to calculate the flow rate to be sent to the lender to repay the stream
    function getPaymentFlowRate() public view returns (int96 paymentFlowRate) {
        return (
            int96(
                ((borrowAmount + ((borrowAmount * int256(interestRate)) / int256(100))) /
                    paybackMonths) / ((365 / 12) * 86400)
            )
        );
    }

    ///get the total amount of super tokens that the borrower still needs to repay on the loan
    ///used to calculate whether or not a loan may be closed
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

    ///lender can use this function to send funds to the borrower and start the loan
    ///function also handles the splitting of flow to lender
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

    ///handle the case of a stream being created into the contract
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

    ///manages edge cases related to flow updates
    ///if flowrate into the contract is enough to cover loan repayment, then just update outflow to borrower
    ///if flowrate into contract is not enough to cover loan repayment, we need to ensure that the lender gets everything going into the contract
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
            //if there is currently an outflow to the lender
            if (outFlowRateLender > 0) {
                //if the borrower is receiving money
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
            //the following case is here because the lender will be paid first
            //if there's not enough money to pay off the loan in full, the lender gets paid everything coming in to the contract
        } else if ((inFlowRate - paymentFlowRate <= 0) && inFlowRate > 0) {
            //if inFlowRate is less than the required amount to pay interest, but there's still a flow, we'll stream it all to the lender
            if (outFlowRateLender > 0) {
                newCtx = cfaV1.deleteFlowWithCtx(newCtx, address(this), borrower, borrowToken);
                newCtx = cfaV1.updateFlowWithCtx(newCtx, lender, borrowToken, inFlowRate);
            } else {
                //in this case, there is no lender outFlowRate..so we need to just update the outflow to borrower
                newCtx = cfaV1.updateFlowWithCtx(newCtx, borrower, borrowToken, inFlowRate);
            }
        }
    }

    ///handles deletion of flow into contract
    ///ensures that streams sent out of the contract are also stopped
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

    ///handles create, update, and delete case - to be run in each callback
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
        require(getTotalAmountRemaining() <= 0);

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

        //lender may close the loan early to forgive the debt
        if (msg.sender == lender) {
            cfaV1.deleteFlow(address(this), lender, borrowToken);
            cfaV1.updateFlow(borrower, borrowToken, currentFlowRate + currentLenderFlowRate);
            loanOpen = false;
        } else {
            require(amountForPayoff >= (getTotalAmountRemaining()), "insuf funds");
            require(getTotalAmountRemaining() > 0, "you should call closeOpenLoan() instead");
            borrowToken.transferFrom(msg.sender, lender, amountForPayoff);

            cfaV1.deleteFlow(address(this), lender, borrowToken);

            cfaV1.updateFlow(borrower, borrowToken, currentFlowRate + currentLenderFlowRate);
            loanOpen = false;
        }
    }

    function afterAgreementCreated(
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
