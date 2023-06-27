// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/// @title Proxy Factory Events
interface ISpaceCollectionFactoryEvents {
    /// @notice Emitted when a new proxy is deployed.
    /// @param implementation The address of the implementation contract.
    /// @param proxy The address of the proxy contract, determined via CREATE2.
    event ProxyDeployed(address implementation, address proxy);

    /// @notice Emitted when the verified signer is updated.
    /// @param _verifiedSigner the new verified signer.
    event VerifiedSignerUpdated(address _verifiedSigner);

    /// @notice Emitted when the snapshot owner is updated.
    /// @param _snapshotOwner the new snapshot owner.
    event SnapshotOwnerUpdated(address _snapshotOwner);

    /// @notice Emitted when the snapshot treasury is updated.
    /// @param _snapshotTreasury the new snapshot treasury.
    event SnapshotTreasuryUpdated(address _snapshotTreasury);
}
