
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

/**
 * @title Storage
 * @dev Store & retrieve value in a variable
 * @custom:dev-run-script ./scripts/deploy_with_ethers.ts
 */

import {ISuperfluid, ISuperToken, ISuperApp, SuperAppDefinitions} from "./contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISuperfluidPool} from "./contracts/interfaces/agreements/gdav1/ISuperfluidPool.sol";
import {SuperTokenV1Library} from "./contracts/apps/SuperTokenV1Library.sol";
import {SuperAppBaseFlow} from "./contracts/apps/SuperAppBaseFlow.sol";
import {IGeneralDistributionAgreementV1,ISuperfluidPool,PoolConfig} from "./contracts/interfaces/agreements/gdav1/IGeneralDistributionAgreementV1.sol";

 
contract AdSpotContract is SuperAppBaseFlow {

    using SuperTokenV1Library for ISuperToken;

    uint256 private number;
    address private poolAddress;
    ISuperfluidPool pool;
    ISuperToken acceptedToken;
    address private owner;
    address public highestBidder;
    int96 private highestFlowRate;
    uint private lastUpdate;
    PoolConfig private poolConfig;
    IGeneralDistributionAgreementV1 private gda;

    event newHighestBidder(address highestBidder, int96 flowRate );

    /**
     * @dev Constructor to initialize the contract with necessary Superfluid interfaces and parameters.
     * @param _acceptedToken The SuperToken accepted for streaming payments.
     * @param _gda General Distribution Agreement interface for handling fund distributions.
     */

    constructor(
        ISuperToken _acceptedToken,
        IGeneralDistributionAgreementV1 _gda
    ) SuperAppBaseFlow(
        ISuperfluid(ISuperToken(_acceptedToken).getHost()), 
        true, 
        true, 
        true,
        string("")
    ) {
        gda=_gda;
        acceptedToken=_acceptedToken;
        poolConfig.transferabilityForUnitsOwner=true;
        poolConfig.distributionFromAnyAddress=true;
        pool=SuperTokenV1Library.createPool(acceptedToken, address(this), poolConfig );
        poolAddress=address(pool);
        owner=msg.sender;
        highestFlowRate=acceptedToken.getFlowRate(owner, address(this));
        lastUpdate=block.timestamp;
        highestBidder=address(0);
    }

    function isAcceptedSuperToken(ISuperToken superToken) public view override returns (bool) {
        return superToken == acceptedToken;
    }

    // ---------------------------------------------------------------------------------------------
    // SUPER APP CALLBACKS
    // ---------------------------------------------------------------------------------------------

    /*
     * @dev Callback function that gets executed when a new flow is created to this contract.
     *      It handles logic for updating the highest bidder and distributing shares.
     * @param sender The address of the sender creating the flow.
     * @param ctx The context of the current flow transaction.
     * @return bytes Returns the new transaction context.
     */
    function onFlowCreated(
        ISuperToken /*superToken*/,
        address sender,
        bytes calldata ctx
    ) internal override returns (bytes memory newCtx) {
        int96 senderFlowRate= acceptedToken.getFlowRate(sender, address(this));
        require(senderFlowRate>highestFlowRate, "Sender flowrate lower than current flowRate");
        newCtx=ctx;
        if(highestBidder!=address(0)){
            newCtx=acceptedToken.deleteFlowWithCtx(highestBidder,address(this), ctx);
        }
        uint128 halfShares=uint128(block.timestamp-lastUpdate)/2;
        pool.updateMemberUnits(owner,halfShares);
        if (highestBidder!=address(0)){
            ISuperfluidPool(poolAddress).updateMemberUnits(highestBidder,halfShares);
        }
        newCtx=acceptedToken.distributeFlowWithCtx(pool,address(this),senderFlowRate,newCtx);
        highestBidder=sender;
        highestFlowRate=senderFlowRate;
        lastUpdate=block.timestamp;
        return newCtx;
    }

    /*
     * @dev Callback function that gets executed when an existing flow to this contract is updated.
     *      It updates the highest bidder and adjusts share distribution accordingly.
     * @param sender The address of the sender updating the flow.
     * @param previousflowRate The previous flow rate before the update.
     * @param lastUpdated The timestamp of the last update.
     * @param ctx The context of the current flow transaction.
     * @return bytes Returns the new transaction context.
     */
    function onFlowUpdated( 
        ISuperToken,
        address sender,
        int96 previousflowRate,
        uint256 lastUpdated,
        bytes calldata ctx
    ) internal override returns (bytes memory newCtx) {
        int96 senderFlowRate= acceptedToken.getFlowRate(sender, address(this));
        require(senderFlowRate>previousflowRate, "Sender flowRate is lower than the previous one");
        require(senderFlowRate>highestFlowRate, "You already have a flowrate that is higher than this one");
        newCtx=ctx;
        uint128 halfShares=uint128(block.timestamp-lastUpdate)/2;
        ISuperfluidPool(poolAddress).updateMemberUnits(owner,halfShares);
        ISuperfluidPool(poolAddress).updateMemberUnits(highestBidder,halfShares);
        newCtx=acceptedToken.distributeFlowWithCtx(pool,address(this),senderFlowRate,newCtx);
        highestBidder=sender;
        highestFlowRate=senderFlowRate;
        lastUpdate=block.timestamp;
        return newCtx;
    }

    /*
     * @dev Callback function that gets executed when a flow to this contract is deleted.
     *      Handles the removal of a bidder and adjustment of shares.
     * @param sender The address of the sender deleting the flow.
     * @param ctx The context of the current flow transaction.
     * @return bytes Returns the new transaction context.
     */

    function onFlowDeleted(
        ISuperToken /*superToken*/,
        address sender,
        address /*receiver*/,
        int96 previousFlowRate,
        uint256 /*lastUpdated*/,
        bytes calldata ctx
    ) internal override returns (bytes memory newCtx) {

        require(sender==highestBidder, "You don't have an active stream");
        highestBidder=address(0);
        uint128 halfShares=uint128(block.timestamp-lastUpdate)/2;
        pool.updateMemberUnits(owner,halfShares);
        if (highestBidder!=address(0)){
            ISuperfluidPool(poolAddress).updateMemberUnits(highestBidder,halfShares);
        }
        newCtx=gda.distributeFlow(acceptedToken, address(this),pool,0,newCtx);

        return newCtx;

    }


}