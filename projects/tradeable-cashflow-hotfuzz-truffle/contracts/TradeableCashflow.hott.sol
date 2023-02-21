// SPDX-License-Identifier: MIT
// solhint-disable not-rely-on-time
pragma solidity ^0.8.14;

import "@superfluid-finance/hot-fuzz/contracts/HotFuzzBase.sol";

import {TradeableCashflow} from "./TradeableCashflow.sol";

//tester must have all the behavior that you need later
//SuperfluidTester has sf functionality
contract NFTHolder is SuperfluidTester {
    TradeableCashflow private _app;

    constructor(
        SuperfluidFrameworkDeployer.Framework memory sf,
        IERC20 token,
        ISuperToken superToken,
        TradeableCashflow app
    ) SuperfluidTester(sf, token, superToken) {
        _app = app;
    }

    function setApp(TradeableCashflow app) external {
        _app = app;
    }
}

contract TradeableCashflowHotFuzz is HotFuzzBase {
    TradeableCashflow private immutable _app;

    constructor(
        address owner,
        string memory name,
        string memory symbol,
        ISuperfluid sf,
        IConstantFlowAgreementV1 cfa,
        ISuperToken superToken
    ) HotFuzzBase(10) {
        initTesters();
        //setup app
        _app = new TradeableCashflow(address(testers[0]), "Trad CF", "TCF", sf, cfa, superToken);
        for (uint i = 0; i < nTesters; i++) {
            NFTHolder(address(testers[i])).setApp(_app);
        }
        addAccount(address(_app));
    }

    // function createTester() override internal returns (SuperfluidTester) {
    //     return new NFTHolder(sf, token, superToken);
    // }

    //Tester Actions

    //Invariances

    //transfer NFT

    //
}
