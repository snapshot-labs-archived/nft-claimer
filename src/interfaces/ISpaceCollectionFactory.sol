// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { ISpaceCollectionFactoryErrors } from "./factory/ISpaceCollectionFactoryErrors.sol";
import { ISpaceCollectionFactoryEvents } from "./factory/ISpaceCollectionFactoryEvents.sol";

/// @title Proxy Factory Interface
interface ISpaceCollectionFactory is ISpaceCollectionFactoryErrors, ISpaceCollectionFactoryEvents {
    /// @notice Appends `snapshotFee`, `verifiedSigner`, `snapshotOwner` and `snapshotTreasury` to the initializer.
    /// @param  initializer the incomplete initializer bytes.
    /// @dev    This function is a bit of a workaround around the fact that `abi.decodeWithSelector` doesn't exist. Because
    ///         of how encoding works in solidity, we first need to decode the initializer, append our data
    ///         and re-encode it. We cannot slice bytes that would be in `memory` so we make this function
    ///         a *public* function and call `this.getInitializer`. Since this function doesn't manipulate any
    ///         sensitive information, it's ok to have it be a public function.
    /// @dev    Please note that the expected abi is 4 bytes for the selector, *then* the data. Some encoding schemas
    ///         treat `selector` as a full word (32 bytes), and this would break this function.
    function getInitializer(bytes calldata initializer) external view returns (bytes memory);

    /// @notice Set the `verifiedSigner` value.
    /// @param  _verifiedSigner the new trusted backend.
    function setVerifiedSigner(address _verifiedSigner) external;

    /// @notice Set the `snapshotOwner` value.
    /// @param  _snapshotOwner the new snapshotOwner.
    function setSnapshotOwner(address _snapshotOwner) external;

    /// @notice Set the `snapshotTreasury` value.
    /// @param  _snapshotTreasury the new snapshotTreasury.
    function setSnapshotTreasury(address _snapshotTreasury) external;

    /// @notice Deploys a proxy contract using the given implementation and initializer function call.
    /// @param implementation The address of the implementation contract.
    /// @param initializer ABI encoded function call to initialize the proxy.
    function deployProxy(
        address implementation,
        bytes memory initializer,
        uint256 salt,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /// @notice Predicts the CREATE2 address of a proxy contract.
    /// @param implementation The address of the implementation contract.
    /// @param salt The CREATE2 salt used.
    function predictProxyAddress(address implementation, uint256 salt) external view returns (address);
}
