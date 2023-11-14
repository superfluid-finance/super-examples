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
    int96 private ownerFlowRate;
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
        ownerFlowRate=acceptedToken.getFlowRate(owner, address(this));
        lastUpdate=block.timestamp;

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
        bytes memory newCtx=ctx;
        require(senderFlowRate>ownerFlowRate, "Sender flowrate lower than owner's");
        newCtx=acceptedToken.deleteFlowWithCtx(owner,address(this), ctx);
        ISuperfluidPool(poolAddress).updateMemberUnits(owner,uint128(block.timestamp-lastUpdate));
        newCtx=gda.distributeFlow(acceptedToken, address(this),pool,senderFlowRate,newCtx);
        owner=sender;
        ownerFlowRate=senderFlowRate;
        lastUpdate=block.timestamp;
        return newCtx;
    }

    function onFlowUpdated( 
        ISuperToken /*superToken*/,
        address sender,
        int96 /*previousflowRate*/,
        uint256 /*lastUpdated*/,
        bytes calldata /*ctx*/
    ) internal override pure returns (bytes memory) {
        // users can't update their flow. They need to stop playing and leave and rejoin the waiting room
        revert("can't update sorry bye");
        // return ctx
    }

    function onFlowDeleted(
        ISuperToken /*superToken*/,
        address sender,
        address /*receiver*/,
        int96 previousFlowRate,
        uint256 /*lastUpdated*/,
        bytes calldata ctx
    ) internal override returns (bytes memory newCtx) {

    }


}