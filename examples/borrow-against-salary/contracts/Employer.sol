// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ISuperfluid, ISuperToken, ISuperApp, ISuperAgreement, SuperAppDefinitions} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import {EmploymentLoan} from "./EmploymentLoan.sol";

import {CFAv1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";

import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import {SuperAppBase} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";

struct PaymentFlow {
    address wallet;
    int96 flowRate;
}

contract Employer is SuperAppBase {
    using CFAv1Library for CFAv1Library.InitData;

    /// @notice Importing the CFAv1 Library to make working with streams easy.
    CFAv1Library.InitData public cfaV1;

    /// @notice Constant used for initialization of CFAv1 and for callback modifiers.
    bytes32 public constant CFA_ID =
        keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");

    address public payrollAddress;

    mapping(uint256 => PaymentFlow) public payroll;

    uint256 public employeeCount;

    int96 public totalPayrollFlowRate;

    /// @notice Superfluid Host.
    ISuperfluid public immutable host;

    /// @notice Token being borrowed.
    ISuperToken public immutable payrollToken;

    // ---------------------------------------------------------------------------------------------
    //MODIFIERS

    /// @dev checks that only the CFA is being used
    ///@param agreementClass the address of the agreement which triggers callback
    function _isCFAv1(address agreementClass) private view returns (bool) {
        return ISuperAgreement(agreementClass).agreementType() == CFA_ID;
    }

    ///@dev checks that only the payrollToken is used when sending streams into this contract
    ///@param superToken the token being streamed into the contract
    function _isSameToken(ISuperToken superToken) private view returns (bool) {
        return address(superToken) == address(payrollToken);
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

    constructor (
        ISuperToken _payrollToken,
        ISuperfluid _host
    ) {
        payrollToken = _payrollToken;
        host = _host;
        payrollAddress = msg.sender;
        employeeCount = 0;
        totalPayrollFlowRate = 0;

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

    function addEmployee(address wallet, int96 daily_payment) public returns (uint256) {
        int96 flowRate = daily_payment * int96(11574074000000);

        (, int96 payrollFlowRate, , ) = cfaV1.cfa.getFlow(payrollToken, payrollAddress, address(this));
        require(payrollFlowRate >= totalPayrollFlowRate + flowRate );

        cfaV1.createFlow(wallet, payrollToken, flowRate);

        totalPayrollFlowRate += flowRate;

        PaymentFlow memory paymentFlow = PaymentFlow(wallet, flowRate);

        employeeCount++;

        payroll[employeeCount] = paymentFlow;

        return employeeCount;
    }

    function updatePaymentFlow(uint256 employeeId, int96 daily_payment) public {
        int96 flowRate = daily_payment * int96(11574074000000);

        PaymentFlow memory oldPaymentFlow = payroll[employeeId];
        int96 oldFlowRate = oldPaymentFlow.flowRate;
        address wallet = oldPaymentFlow.wallet;

        int96 deltaFlowRate = flowRate - oldFlowRate;

        (, int96 payrollFlowRate, , ) = cfaV1.cfa.getFlow(payrollToken,  address(this), wallet);
        require(payrollFlowRate >= totalPayrollFlowRate + deltaFlowRate );

        PaymentFlow memory paymentFlow = PaymentFlow(oldPaymentFlow.wallet, flowRate);

        cfaV1.updateFlow(
            wallet,
            payrollToken,
            flowRate
        );

        payroll[employeeId] = paymentFlow;

        totalPayrollFlowRate += deltaFlowRate;
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
        newCtx = ctx;
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
        newCtx = ctx;
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
        newCtx = ctx;
    }
}


// TODO: Grant permission to create channel by this contract.
// TODO: Add handling of closing contracts.

// TODO: Abstract duplicated functionality in Employer and EmploymentLoan.