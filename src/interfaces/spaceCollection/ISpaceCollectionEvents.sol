// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/// @title Space Collection Events
interface ISpaceCollectionEvents {
    /// @notice Emitted when `maxSupply` is updated.
    event MaxSupplyUpdated(uint128 maxSupply);

    /// @notice Emitted when `mintPrice` is updated.
    event MintPriceUpdated(uint256 mintPrice);

    /// @notice Emitted space collection is disabled / re-enabled.
    event PowerSwitchUpdated(bool enable);

    /// @notice Emitted when `proposerFee` is updated.
    event ProposerFeeUpdated(uint8 proposerFee);
    /// @notice Emitted when a new space collection is created.
    event SpaceCollectionCreated(
        string name,
        uint128 maxSupply,
        uint256 mintPrice,
        uint8 proposerFee,
        address spaceTreasury,
        address spaceOwner,
        uint8 snapshotFee,
        address verifiedSigner,
        address snapshotOwner,
        address snapshotTreasury
    );

    event SpaceTreasuryUpdated(address spaceTreasury);

    /// @notice Emitted when `snapshotFee` is updated.
    event SnapshotFeeUpdated(uint8 snapshotFee);

    /// @notice Emitted when `snapshotOwner` is updated.
    event SnapshotOwnerUpdated(address snapshotOwner);

    /// @notice Emitted when `snapshotTreasury` is updated.
    event SnapshotTreasuryUpdated(address snapshotTreasury);

    /// @notice Emitted when `verifiedSigner` is updated.
    event VerifiedSignerUpdated(address _verifiedSigner);
}
