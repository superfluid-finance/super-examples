// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import {RedirectAll, ISuperToken, ISuperfluid, IConstantFlowAgreementV1} from "./RedirectAll.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

/// @title Tradeable Cashflow NFT
/// @notice Inherits the ERC721 NFT interface from Open Zeppelin and the RedirectAll logic to
/// redirect all incoming streams to the current NFT holder.
contract TradeableCashflow is ERC721, RedirectAll {
    using SuperTokenV1Library for ISuperToken;

    int96 public minFlowRate;
    address owner;

    constructor(
        address _owner,
        string memory _name,
        string memory _symbol,
        int96 initialMintFlowRate,
        ISuperfluid host,
        IConstantFlowAgreementV1 cfa,
        ISuperToken acceptedToken
    ) ERC721(_name, _symbol) RedirectAll(acceptedToken, host, cfa, _owner) {
        _mint(owner, 1);
        minFlowRate = initialMintFlowRate;
        owner = _owner;
    }

    function changeOwner(address newOwner) external {
        require(msg.sender == owner, "only owner can call");
        owner = newOwner;
    }

    function changeMinFlowRate(int96 newMinFlowRate) external {
        require(msg.sender == owner, "only owner can change flowRate");
        minFlowRate = newMinFlowRate;
    }

    modifier onlySubscribers(address recipient) {
        (startTime, flowrate, , ) = acceptedToken.getFlowInfo(msg.sender, recipient);
        require(flowrate > minFlowrate, "please subscribe to call");
        _;
    }

    /// @dev Override mint function such that the caller must be streaming to contract
    /// defined in `RedirectAll`.
    /// @param to New receiver.
    function mint(address to, uint id) public override onlySubscribers(to) {
        _mint(to, id);
    }

    // ---------------------------------------------------------------------------------------------
    // BEFORE TOKEN TRANSFER CALLBACK

    /// @dev Before transferring the NFT, set the token receiver to be the stream receiver as
    /// defined in `RedirectAll`.
    /// @param to New receiver.
    function _beforeTokenTransfer(
        address from, // from
        address to,
        uint256 tokenId, // tokenId
        uint256 //open zeppelin's batchSize param
    ) internal override {
        _changeReceiver(to);
    }
}
