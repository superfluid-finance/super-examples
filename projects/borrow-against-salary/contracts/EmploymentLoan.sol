// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ISuperfluid, ISuperToken, ISuperApp, ISuperAgreement, SuperAppDefinitions} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import {CFAv1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";

import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import {SuperAppBase} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";

/// @title Employment Loan Contract
/// @author Superfluid
contract EmploymentLoan is SuperAppBase {
    using CFAv1Library for CFAv1Library.InitData;

    // ---------------------------------------------------------------------------------------------
    // STORAGE & IMMUTABLES

    /// @notice Importing the CFAv1 Library to make working with streams easy.
    CFAv1Library.InitData public cfaV1;

    /// @notice Constant used for initialization of CFAv1 and for callback modifiers.
    bytes32 public constant CFA_ID =
        keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");

    /// @notice Total amount borrowed.
    int256 public immutable borrowAmount;

    /// @notice Interest rate, in whole number. I.e. 8% interest rate would be passed as '8'
    int8 public immutable interestRate;

    /// @notice Number of months the loan will be paid back in. I.e. 2 years = '24'
    int256 public immutable paybackMonths;

    /// @notice Address of employer - must be allow-listed for this example
    address public immutable employer;

    /// @notice Borrower address.
    address public immutable borrower;

    /// @notice Superfluid Host.
    ISuperfluid public immutable host;

    /// @notice Token being borrowed.
    ISuperToken public immutable borrowToken;

    /// @notice Lender address.
    address public lender;

    /// @notice boolean flag to track whether or not the loan is open
    bool public loanOpen;

    /// @notice Timestamp of the loan start time.
    uint256 public loanStartTime;

    // ---------------------------------------------------------------------------------------------
    //MODIFIERS

    /// @dev checks that only the CFA is being used
    ///@param agreementClass the address of the agreement which triggers callback
    function _isCFAv1(address agreementClass) private view returns (bool) {
        return ISuperAgreement(agreementClass).agreementType() == CFA_ID;
    }

    ///@dev checks that only the borrowToken is used when sending streams into this contract
    ///@param superToken the token being streamed into the contract
    function _isSameToken(ISuperToken superToken) private view returns (bool) {
        return address(superToken) == address(borrowToken);
    }

    ///@dev ensures that only the host can call functions where this is implemented
    //for usage in callbacks only
    modifier onlyHost() {
        require(msg.sender == address(cfaV1.host), "Only host can call callback");
        _;
    }

    ///@dev used to implement _isSameToken and _isCFAv1 modifiers
    ///@param superToken used when sending streams into contract to trigger callbacks
    ///@param agreementClass the address of the agreement which triggers callback
    modifier onlyExpected(ISuperToken superToken, address agreementClass) {
        require(_isSameToken(superToken), "RedirectAll: not accepted token");
        require(_isCFAv1(agreementClass), "RedirectAll: only CFAv1 supported");
        _;
    }

    constructor(
        int256 _borrowAmount, // amount to be borrowed
        int8 _interestRate, // annual interest rate, in whole number - i.e. 8% would be passed as 8
        int256 _paybackMonths, // total payback months
        address _employer, // allow-listed employer address
        address _borrower, // borrower address
        ISuperToken _borrowToken, // super token to be used in borrowing
        ISuperfluid _host // address of SF host
    ) {
        borrowAmount = _borrowAmount;
        interestRate = _interestRate;
        paybackMonths = _paybackMonths;
        employer = _employer;
        borrower = _borrower;
        borrowToken = _borrowToken;
        host = _host;
        loanOpen = false;

        // CFA lib initialization
        IConstantFlowAgreementV1 cfa = IConstantFlowAgreementV1(
            address(_host.getAgreementClass(CFA_ID))
        );

        cfaV1 = CFAv1Library.InitData(_host, cfa);

        // super app registration
        uint256 configWord = SuperAppDefinitions.APP_LEVEL_FINAL |
            SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;

        // Using host.registerApp because we are using testnet. If you would like to deploy to
        // mainnet, this process will work differently. You'll need to use registerAppWithKey or
        // registerAppByFactory.
        // https://github.com/superfluid-finance/protocol-monorepo/wiki/Super-App-White-listing-Guide
        _host.registerApp(configWord);
    }

    /// @dev Calculates the flow rate to be sent to the lender to repay the stream.
    /// @return paymentFlowRate The flow rate to be paid to the lender.
    function getPaymentFlowRate() public view returns (int96 paymentFlowRate) {
        return (
            int96(
                ((borrowAmount + ((borrowAmount * int256(interestRate)) / int256(100))) /
                    paybackMonths) / ((365 / 12) * 86400)
            )
        );
    }

    // ---------------------------------------------------------------------------------------------
    // FUNCTIONS & CORE LOGIC

    /// @notice Get the total amount of super tokens that the borrower still needs to repay on the
    /// loan.
    /// @return Total number of remaining tokens to be paid on the loan in wei used to calculate
    /// whether or not a loan may be closed.
    function getTotalAmountRemaining() public view returns (uint256) {
        //if there is no time left on loan, return zero
        int256 secondsLeft = (paybackMonths * int256((365 * 86400) / 12)) -
            int256(block.timestamp - loanStartTime);
        if (secondsLeft <= 0) {
            return 0;
        } else {
            //if an amount is left, return the total amount to be paid
            return uint256(secondsLeft) * uint256(int256(getPaymentFlowRate()));
        }
    }

    /// @notice lender can use this function to send funds to the borrower and start the loan
    /// @dev function also handles the splitting of flow to lender
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

    /// @notice handle the case of a stream being created into the contract
    /// @param ctx the context value passed into updateOutflow in super app callbacks
    /// @param paymentFlowRate the flow rate to be sent to the lender if a loan were to activate
    /// (this could be the same value as outFlowRate)
    /// @param inFlowRate the flow rate sent into the contract from the employer
    /// used within the _updateOutflow function which is ultimately called in the callbacks
    function _updateOutFlowCreate(
        bytes calldata ctx,
        int96 paymentFlowRate,
        int96 inFlowRate
    ) private returns (bytes memory newCtx) {
        newCtx = ctx;
        //get the current sender of the flow
        address sender = host.decodeCtx(ctx).msgSender;
        //this will revert and no outflow or inflow will be created if the sender of the flow is not
        // the emploer
        require(sender == employer, "sender of flow must be the employer");
        // @dev If there is no existing outflow, then create new flow to equal inflow
        // sender must also be the employer
        //create flow to employee
        //if loan is still open, we need to make sure that the right amount of funds are sent to the
        // borrower & lender
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

    /// @dev manages edge cases related to flow updates
    /// to be used within _updateOutflow function
    /// @param ctx context passed by super app callback
    /// @param paymentFlowRate the flow rate to be sent to the lender if a loan were to activate
    /// (this could be the same value as outFlowRate)
    /// @param outFlowRateLender the flow rate being sent to lender from the contract
    /// @param inFlowRate the flow rate sent into the contract from the employer
    /// @dev if flowrate into the contract is enough to cover loan repayment, then just update
    /// outflow to borrower. if flowrate into contract is not enough to cover loan repayment, we
    /// need to ensure that the lender gets everything going into the contract
    function _updateOutFlowUpdate(
        bytes calldata ctx,
        int96 paymentFlowRate,
        int96 outFlowRateLender,
        int96 inFlowRate
    ) private returns (bytes memory newCtx) {
        newCtx = ctx;
        // this will get us the amount of money that should be redirected to the lender out of the
        // inflow, denominated in borrow token

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
            // the following case is here because the lender will be paid first
            // if there's not enough money to pay off the loan in full, the lender gets paid
            // everything coming in to the contract
        } else if ((inFlowRate - paymentFlowRate <= 0) && inFlowRate > 0) {
            // if inFlowRate is less than the required amount to pay interest, but there's still a
            // flow, we'll stream it all to the lender
            if (outFlowRateLender > 0) {
                newCtx = cfaV1.deleteFlowWithCtx(newCtx, address(this), borrower, borrowToken);
                newCtx = cfaV1.updateFlowWithCtx(newCtx, lender, borrowToken, inFlowRate);
            } else {
                //in this case, there is no lender outFlowRate..so we need to just update the outflow to borrower
                newCtx = cfaV1.updateFlowWithCtx(newCtx, borrower, borrowToken, inFlowRate);
            }
        }
    }

    /// @notice handles deletion of flow into contract
    /// @dev ensures that streams sent out of the contract are also stopped
    /// @param ctx context passed by super app callback
    /// @param outFlowRateLender the flow rate being sent to lender from the contract
    function _updateOutFlowDelete(bytes calldata ctx, int96 outFlowRateLender)
        private
        returns (bytes memory newCtx)
    {
        newCtx = ctx;
        // delete flow to lender in borrow token if they are currently receiving a flow
        if (outFlowRateLender > 0) {
            newCtx = cfaV1.deleteFlowWithCtx(newCtx, address(this), lender, borrowToken);
        }
        // delete flow to borrower in borrow token
        newCtx = cfaV1.deleteFlowWithCtx(newCtx, address(this), borrower, borrowToken);
    }

    /// @notice handles create, update, and delete case - to be run in each callback
    /// @param ctx context passed by super app callback
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

    /// @notice function to close a loan that is already completed
    function closeCompletedLoan() external {
        require(getTotalAmountRemaining() <= 0);

        (, int96 currentLenderFlowRate, , ) = cfaV1.cfa.getFlow(borrowToken, address(this), lender);
        cfaV1.deleteFlow(address(this), lender, borrowToken);

        (, int96 currentFlowRate, , ) = cfaV1.cfa.getFlow(borrowToken, address(this), borrower);
        cfaV1.updateFlow(borrower, borrowToken, currentFlowRate + currentLenderFlowRate);
        loanOpen = false;
    }

    ///@notice allows lender or borrower to close a loan that is not yet finished
    ///@param amountForPayoff the amount to be paid right now to close the loan in wei
    /// @dev if the loan is paid off, or if the loan is closed by the lender, pass 0. if the loan is
    /// not yet paid off, pass in the required amount to close loan
    function closeOpenLoan(uint256 amountForPayoff) external {
        (, int96 currentLenderFlowRate, , ) = cfaV1.cfa.getFlow(borrowToken, address(this), lender);
        (, int96 currentFlowRate, , ) = cfaV1.cfa.getFlow(borrowToken, address(this), borrower);

        // lender may close the loan early to forgive the debt
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

    // ---------------------------------------------------------------------------------------------
    // SUPER APP CALLBACKS

    /// @dev super app after agreement created callback
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

    /// @dev super app after agreement updated callback
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

    /// @dev super app after agreement terminated callback
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
}
