// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { ISpaceCollectionErrors } from "./spaceCollection/ISpaceCollectionErrors.sol";
import { ISpaceCollectionEvents } from "./spaceCollection/ISpaceCollectionEvents.sol";

interface ISpaceCollection is ISpaceCollectionErrors, ISpaceCollectionEvents {
    function initialize(
        string memory name,
        string memory version,
        uint128 _maxSupply,
        uint256 _mintPrice,
        uint8 _proposerFee,
        address _spaceTreasury,
        address _spaceOwner,
        uint8 _snapshotFee,
        address _verifiedSigner,
        address _snapshotOwner,
        address _snapshotTreasury
    ) external;

    /// @notice Updates the different collection settings.
    /// @param maxSupply The maximum supply for new collections (set to `NO_UPDATE_U128` to ignore).
    /// @param mintPrice The mint price for new collections (set to `NO_UPDATE_U256` to ignore).
    /// @param proposerFee The proposer fee for new collections (set to `NO_UPDATE_U8` to ignore).
    /// @param spaceTreasury The new space treasury (set to `NO_UPDATE_ADDRESS` to ignore).
    function updateSettings(uint128 maxSupply, uint256 mintPrice, uint8 proposerFee, address spaceTreasury) external;

    /// @notice Updates the different snapshot settings.
    /// @param snapshotFee The snapshot fee for new collections (set to `NO_UPDATE_U8` to ignore). This fee
    ///                     will have priority over `proposerFee`, i.e. if `snapshotFee + priorityFee > 100` then
    ///                     we will set priorityFee to `priorityFee = 100 - snapshotFee`.
    /// @param snapshotTreasury The snapshot treasury (set to `NO_UPDATE_ADDRESS` to ignore).
    /// @param verifiedSigner The verified signer (set to `NO_UPDATE_ADDRESS` to ignore).
    function updateSnapshotSettings(uint8 snapshotFee, address snapshotTreasury, address verifiedSigner) external;

    /// @notice Updates the snapshot owner.
    /// @param snapshotOwner The address of the new snapshot owner.
    function setSnapshotOwner(address snapshotOwner) external;

    /// @notice Turns on / off the minting.
    /// @param enable Set to true to enable minting ; set to false to disable minting.
    function setPowerSwitch(bool enable) external;

    /// @notice Mints a new NFT.
    /// @param proposer The address of the proposer of this proposal.
    /// @param proposalId The proposal ID.
    /// @param salt A salt to avoid replay attacks on the signature.
    /// @param v The v parameter of the signature.
    /// @param r The r parameter of the signature.
    /// @param s The s parameter of the signature.
    function mint(address proposer, uint256 proposalId, uint256 salt, uint8 v, bytes32 r, bytes32 s) external;

    /// @notice Mints new NFTs.
    /// @param proposers An array of addresses corresponding to the proposers of each proposal.
    /// @param proposalIds An array of proposal IDs.
    /// @param salt A salt to avoid replay attacks on the signature.
    /// @param v The v parameter of the signature.
    /// @param r The r parameter of the signature.
    /// @param s The s parameter of the signature.
    function mintBatch(
        address[] calldata proposers,
        uint256[] calldata proposalIds,
        uint256 salt,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}
