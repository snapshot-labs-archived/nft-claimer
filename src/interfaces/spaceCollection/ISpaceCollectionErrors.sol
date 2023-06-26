// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/// @title Proxy Factory Errors
interface ISpaceCollectionErrors {
    /// @notice Thrown if trying to set `verifiedSigner` to 0.
    error AddressCannotBeZero();

    /// @notice Thrown if caller is not `snapshotOwner`.
    error CallerIsNotSnapshot();

    /// @notice Thrown if the space collection is currently disabled.
    error Disabled();

    /// @notice Thrown if duplicates are found in `_assertNoDuplicates()`.
    error DuplicatesFound();

    /// @notice Thrown if a fee is invalid (i.e >100 or sum of snapshotFee and proposerFee > 100).
    error InvalidFee();

    /// @notice Thrown if a signature is invalid.
    error InvalidSignature();

    /// @notice Thrown if the maximum supply has been reached.
    error MaxSupplyReached();

    /// @notice Thrown if a user has already used a specific salt.
    error SaltAlreadyUsed();

    /// @notice Thrown when trying to set `maxSupply` to 0.
    error SupplyCannotBeZero();
}
