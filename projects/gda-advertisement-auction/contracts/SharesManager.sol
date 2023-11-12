// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

// Key Responsibilities (Only a suggestion, subject to ideal implementation):
// Manage Share Assignment: Allocate shares to advertisers based on the duration and value of their advertisements.
// Update Shares: Adjust shares when a new advertiser starts streaming funds, ensuring the distribution remains fair and proportionate.
// Track Advertisement Duration: Keep a record of the duration each advertiser's content is shown.
// Share Computation: Calculate the shares for distribution from the GDA pool based on advertising time and value contributed.
// Further details:
// Contract can keep track of state or it can just provide methods to be called. These methods need to make it as easy as possible for us to 
//  the state of a specific advertiser (share holder). For example: a method updateShares can take as input the address of the advertiser, 
//  the number of days they have been advertising and some other inputs to update the state of their current shares. Make sure to take care 
//  of edge cases where shares cannot be split, and keep in mind how the GDA pool would interact with these methods.

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {ISuperfluid, ISuperToken, ISuperApp} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

import {SuperAppBaseFlow} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBaseFlow.sol";

// import {SuperfluidPool}

/// @dev Thrown when the receiver is the zero adress.
error InvalidReceiver();

/// @dev Thrown when receiver is also a super app.
error ReceiverIsSuperApp();

/// @title Stream Redirection Contract
/// @notice This contract is a registered super app, meaning it receives
contract SharesManager is SuperAppBaseFlow {
    // SuperToken library setup
    using SuperTokenV1Library for ISuperToken;

    /// @dev Super token that may be streamed to this contract
    ISuperToken internal immutable _acceptedToken;

    /// @notice This is the current receiver that all streams will be redirected to.
    address public _receiver;

    /// @notice The GDA pool
    address public pool;

    constructor(
        ISuperToken acceptedToken,
        ISuperfluid _host,
        address receiver
    ) SuperAppBaseFlow(
      _host,
      true,
      true,
      true  
    ) {

        _acceptedToken = acceptedToken;
        host = _host;
        _receiver = receiver;

    }

    // ---------------------------------------------------------------------------------------------
    // EVENTS

    /// @dev Logged when the receiver changes
    /// @param receiver The new receiver address.
    event ReceiverChanged(address indexed receiver);

    // ---------------------------------------------------------------------------------------------
    // MODIFIERS

    ///@dev checks that only the borrowToken is used when sending streams into this contract
    ///@param superToken the token being streamed into the contract
    function isAcceptedSuperToken(ISuperToken superToken) public view override returns (bool) {
        return superToken == _acceptedToken;
    }

    // ---------------------------------------------------------------------------------------------
    // SHARE MANAGEMENT

    function updateShares(address advertiser, int96 paymentRate) internal {

        _acceptedToken.updateMemberUnits(
            pool,
            advertiser,
            uint128(int(paymentRate))
        );

    }

    // ---------------------------------------------------------------------------------------------

    function getAdvertisingDuration(address advertiser) public {
        
    }

    // ---------------------------------------------------------------------------------------------
    // SUPER APP CALLBACKS

    function onFlowCreated(
        ISuperToken /*superToken*/,
        address sender,
        bytes calldata ctx
    )
        internal
        override
        returns (bytes memory)
    {
        
        updateShares(
            advertiserAddress,
            _acceptedToken.getFlowRate(sender, address(this))
        );

    }

    function onFlowUpdated(
        ISuperToken /*superToken*/,
        address sender,
        int96 /*previousFlowRate*/,
        uint256 /*lastUpdated*/,
        bytes calldata ctx
    )
        internal
        override
        returns (bytes memory)
    {
        
        updateShares(
            advertiserAddress,
            _acceptedToken.getFlowRate(sender, address(this))
        );

    }

    function onFlowDeleted(
        ISuperToken /*superToken*/,
        address /*sender*/,
        address /*receiver*/,
        int96 /*previousFlowRate*/,
        uint256 /*lastUpdated*/,
        bytes calldata ctx
    ) 
        internal
        override
        returns (bytes memory newCtx) 
    {

        // check if you can updateMemberUnits to the same number of units as before and not error
        updateShares(
            advertiserAddress,
            _acceptedToken.getFlowRate(sender, address(this))
        );

    }

}