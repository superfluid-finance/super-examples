// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {SuperAppBaseFlow} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBaseFlow.sol";
import {ISuperfluid, ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

contract Flower is ERC721, SuperAppBaseFlow {
    error InvalidTransfer();
    error InvalidStages();

    /// @dev super token library
    using SuperTokenV1Library for ISuperToken;

    struct FlowerProfile {
        // timestamp where a flower's flow was last modified - created, updated, or deleted to contract
        uint256 latestFlowMod;
        // current flow rate for the flower
        int96 flowRate;
        // amount of water streamed to flower so far upon a flow modification (created/update/delete)
        uint256 streamedSoFarAtLatestMod;
    }

    /// @dev mapping flower nft ids to flower profile info
    mapping(uint256 => FlowerProfile) public flowerProfiles;

    /// @dev mapping of accounts to their flowers (ERC721 gives you token IDs to owners in _owners)
    mapping(address => uint256) public flowerOwned;

    /// @dev metadata for each stage of growth for flower NFTs
    string[] public stageMetadatas;

    /// @dev how much tokens must accumulate must pass for each stage of growth
    uint256[] public stageAmounts;

    /// @dev current token ID
    uint256 public tokenId;

    /// @dev Super token that may be streamed to this contract
    ISuperToken public immutable acceptedToken;

    constructor(
        uint256[] memory _stageAmounts,
        string[] memory _stageMetadatas,
        ISuperToken _acceptedToken,
        ISuperfluid host
    ) ERC721("Flower", "FLWR") SuperAppBaseFlow(host, true, true, true) {
        // need stage amounts for every stage except the final one
        if (_stageAmounts.length == _stageMetadatas.length - 1) revert InvalidStages();

        stageAmounts = _stageAmounts;
        stageMetadatas = _stageMetadatas;
        acceptedToken = _acceptedToken;
    }

    // ---------------------------------------------------------------------------------------------
    // MODIFIERS

    ///@dev checks that only the acceptedToken is used when sending streams into this contract
    ///@param superToken the token being streamed into the contract
    function isAcceptedSuperToken(ISuperToken superToken) public view override returns (bool) {
        return superToken == acceptedToken;
    }

    // ---------------------------------------------------------------------------------------------
    // CALLBACK LOGIC

    function onFlowCreated(
        ISuperToken /*superToken*/,
        address sender,
        bytes calldata ctx
    ) internal override returns (bytes memory /*newCtx*/) {
        // if the flow sender DOESN'T already have a flower
        if (flowerOwned[sender] == 0) {
            tokenId++;

            // mint flower to flow sender
            _mint(sender, tokenId);

            // set the token id for the flow sender
            flowerOwned[sender] = tokenId;
        }

        // update the info for the flow sender's flower
        flowerUpdate(sender, tokenId);

        return ctx;
    }

    function onFlowUpdated(
        ISuperToken /*superToken*/,
        address sender,
        int96 /*previousFlowRate*/,
        uint256 /*lastUpdated*/,
        bytes calldata ctx
    ) internal override returns (bytes memory /*newCtx*/) {
        // get token id for flow sender
        uint256 tokenId = flowerOwned[sender];

        // update the info for the flow sender's flower
        flowerUpdate(sender, tokenId);

        return ctx;
    }

    function onFlowDeleted(
        ISuperToken /*superToken*/,
        address sender,
        address /*receiver*/,
        int96 /*previousFlowRate*/,
        uint256 /*lastUpdated*/,
        bytes calldata ctx
    ) internal override returns (bytes memory /*newCtx*/) {
        // get token id for flow sender
        uint256 tokenId = flowerOwned[sender];

        // update the info for the flow sender's flower
        flowerUpdate(sender, tokenId);

        return ctx;
    }

    function flowerUpdate(address flowSender, uint256 tokenId) internal {
        // update streamedSoFarAtLatestMod to current value of streamedSoFar
        flowerProfiles[tokenId].streamedSoFarAtLatestMod = streamedSoFar(tokenId);

        flowerProfiles[tokenId].flowRate = acceptedToken.getFlowRate(flowSender, address(this));

        // set latestFlowMod to current time stamp
        flowerProfiles[tokenId].latestFlowMod = block.timestamp;
    }

    // ---------------------------------------------------------------------------------------------
    // ERC721

    /// @dev Hook that is called before any token transfer. This includes minting and burning.
    /// @param from Address sending the Flower NFT
    /// @param to Address receiving the Flower NFT
    /// @param tokenId ID of Flower NFT being transfered
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 /* batchSize */
    ) internal override {
        // if it's a transfer
        if (from != address(0)) {
            // flower receiver can't already have a flower
            if (flowerOwned[to] != 0) revert InvalidTransfer();

            // cancel the flower sender's stream
            if (acceptedToken.getFlowRate(from, address(this)) != 0) {
                acceptedToken.deleteFlow(from, address(this));
            }

            // update the flower's info
            flowerUpdate(from, tokenId);

            // update ownership
            flowerOwned[from] = 0;
            flowerOwned[to] = tokenId;
        }
    }

    // ---------------------------------------------------------------------------------------------
    // Read functions

    /// @notice Returns how much has been streamed so far to grow a certain Flower
    /// @param tokenId ID of Flower NFT being queried
    function streamedSoFar(uint256 tokenId) public view returns (uint256) {
        // seconds passed since last flow modification* tokens/second flow rate = tokens streamed since last flow modification
        uint256 streamedSinceLatestMod = uint(int(flowerProfiles[tokenId].flowRate)) *
            (block.timestamp - flowerProfiles[tokenId].latestFlowMod);

        // amount streamed up until last modification (held staticly in mapping) + amount streamed since mod (changing per-second w/ rising block.timestamp)
        return flowerProfiles[tokenId].streamedSoFarAtLatestMod + streamedSinceLatestMod;
    }

    /// @notice Overrides tokenURI
    /// @param tokenId token ID of NFT being queried
    /// @return token URI
    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        // get amount streamed so far
        uint256 _streamedSoFar = streamedSoFar(tokenId);

        // iterate down levels and see which stage the token id has reached
        uint256 stageAmount = stageAmounts[0];
        for (uint256 i = 0; i < 2; i++) {
            // if amount streamed so far is under the stage's amount
            if (_streamedSoFar < stageAmount) {
                // it's within that tier, so return stage metadata
                return stageMetadatas[i];
                // else, the random number is above probability level
            } else {
                // increase probability sum to include next level
                stageAmount += stageAmounts[i];
            }
        }

        // if it's cleared the first two levels, then level 3 is everything beyond, so just return it
        return stageMetadatas[stageMetadatas.length - 1];
    }
}
