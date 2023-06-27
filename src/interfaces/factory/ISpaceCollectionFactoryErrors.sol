// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/// @title Proxy Factory Errors
interface ISpaceCollectionFactoryErrors {
    /// @notice Thrown when the salt supplied to the proxy factory has already been used by another deployment.
    error SaltAlreadyUsed();

    /// @notice Thrown when the proxy factory fails to call the initializer on a proxy.
    error FailedInitialization();

    /// @notice Thrown when the implementation supplied to the proxy factory is the zero address or has no code.
    error InvalidImplementation();

    /// @notice Thrown when trying to set `verifiedSigner` to 0.
    error AddressCannotBeZero();

    /// @notice Thrown when the recovered address does not match the verified signer address.
    error InvalidSignature();
}
