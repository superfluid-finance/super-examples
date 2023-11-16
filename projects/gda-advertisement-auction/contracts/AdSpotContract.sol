// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

/**
 * @title Storage
 * @dev Store & retrieve value in a variable
 * @custom:dev-run-script ./scripts/deploy_with_ethers.ts
 */

import {ISuperfluid, ISuperToken, ISuperApp} from "./contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISuperfluidPool} from "./contracts/interfaces/agreements/gdav1/ISuperfluidPool.sol";
import {SuperTokenV1Library} from "./contracts/apps/SuperTokenV1Library.sol";
import {SuperAppBaseFlow} from "./contracts/apps/SuperAppBaseFlow.sol";
import {IGeneralDistributionAgreementV1,ISuperfluidPool,PoolConfig} from "./contracts/interfaces/agreements/gdav1/IGeneralDistributionAgreementV1.sol";

 
contract Royalties is SuperAppBaseFlow {

    using SuperTokenV1Library for ISuperToken;

    uint256 private number;
    address private poolAddress;
    ISuperfluidPool pool;
    ISuperToken acceptedToken;
    address private owner;
    address private highestBidder;
    int96 private highestFlowRate;
    uint private lastUpdate;
    PoolConfig private poolConfig;
    IGeneralDistributionAgreementV1 private gda;


    constructor(
        ISuperToken _acceptedToken,
        IGeneralDistributionAgreementV1 _gda
    ) SuperAppBaseFlow(
        ISuperfluid(_acceptedToken.getHost()), 
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
    function onFlowCreated(
        ISuperToken /*superToken*/,
        address sender,
        bytes calldata ctx
    ) internal override returns (bytes memory) {
        int96 senderFlowRate= acceptedToken.getFlowRate(sender, address(this));
        require(senderFlowRate>highestFlowRate, "Sender flowrate lower than current flowRate");
        bytes memory newCtx=ctx;
        newCtx=acceptedToken.deleteFlowWithCtx(highestBidder,address(this), ctx);
        uint128 halfShares=uint128(block.timestamp-lastUpdate)/2;
        pool.updateMemberUnits(owner,halfShares);
        if (highestBidder!=address(0)){
            ISuperfluidPool(poolAddress).updateMemberUnits(highestBidder,halfShares);
        }
        newCtx=gda.distributeFlow(acceptedToken, address(this),pool,senderFlowRate,newCtx);
        highestBidder=sender;
        highestFlowRate=senderFlowRate;
        lastUpdate=block.timestamp;
        return newCtx;
    }

    function onFlowUpdated( 
        ISuperToken,
        address sender,
        int96 previousflowRate,
        uint256 lastUpdated,
        bytes calldata ctx
    ) internal override returns (bytes memory) {
        int96 senderFlowRate= acceptedToken.getFlowRate(sender, address(this));
        require(senderFlowRate>previousflowRate, "Sender flowRate is lower than the previous one");
        require(senderFlowRate>highestFlowRate, "Sender flowrate lower than current flowRate");
        bytes memory newCtx=ctx;
        uint128 halfShares=uint128(block.timestamp-lastUpdate)/2;
        ISuperfluidPool(poolAddress).updateMemberUnits(owner,halfShares);
        ISuperfluidPool(poolAddress).updateMemberUnits(highestBidder,halfShares);
        newCtx=gda.distributeFlow(acceptedToken, address(this),pool,senderFlowRate,newCtx);
        highestBidder=sender;
        highestFlowRate=senderFlowRate;
        lastUpdate=block.timestamp;
        return newCtx;
    }

    function onFlowDeleted(
        ISuperToken /*superToken*/,
        address sender,
        address /*receiver*/,
        int96 previousFlowRate,
        uint256 /*lastUpdated*/,
        bytes calldata ctx
    ) internal override returns (bytes memory newCtx) {

        require(sender==highestBidder, "You don't have an active stream");
        bytes memory newCtx=ctx;

        return newCtx;

    }


}