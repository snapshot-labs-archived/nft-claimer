// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { ISpaceCollectionFactoryErrors } from "./factory/ISpaceCollectionFactoryErrors.sol";
import { ISpaceCollectionFactoryEvents } from "./factory/ISpaceCollectionFactoryEvents.sol";

/// @title Proxy Factory Interface
interface ISpaceCollectionFactory is ISpaceCollectionFactoryErrors, ISpaceCollectionFactoryEvents {
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
