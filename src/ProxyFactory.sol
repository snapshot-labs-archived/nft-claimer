// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IProxyFactory } from "./interfaces/IProxyFactory.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/// @title Proxy Factory
/// @notice A contract to deploy and track ERC1967 proxies of a given implementation contract.
contract ProxyFactory is IProxyFactory, Ownable, EIP712 {
    bytes32 private constant DEPLOY_TYPEHASH =
        keccak256("Deploy(address implementation,bytes initializer,uint256 salt)");
    error InvalidSignature();
    address public trustedBackend;
    string constant NAME = "ProxySpaceCollectionFactory";
    string constant VERSION = "1.0";

    constructor(address _trustedBackend) EIP712(NAME, VERSION) {
        trustedBackend = _trustedBackend;
        // TODO: emit event
    }

    function setTrustedBackend(address _trustedBackend) public onlyOwner {
        trustedBackend = _trustedBackend;
        //TODO: emit event
    }

    /// @inheritdoc IProxyFactory
    function deployProxy(
        address implementation,
        bytes memory initializer,
        uint256 salt,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        // Check sig.
        address recoveredAddress = ECDSA.recover(
            _hashTypedDataV4(keccak256(abi.encode(DEPLOY_TYPEHASH, implementation, keccak256(initializer), salt))),
            v,
            r,
            s
        );

        if (recoveredAddress != trustedBackend) revert InvalidSignature();

        if (implementation == address(0) || implementation.code.length == 0) revert InvalidImplementation();
        if (predictProxyAddress(implementation, salt).code.length > 0) revert SaltAlreadyUsed();
        address proxy = address(new ERC1967Proxy{ salt: bytes32(salt) }(implementation, ""));
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = proxy.call(initializer);
        if (!success) revert FailedInitialization();

        emit ProxyDeployed(implementation, proxy);
    }

    /// @inheritdoc IProxyFactory
    function predictProxyAddress(address implementation, uint256 salt) public view override returns (address) {
        return
            address(
                uint160(
                    uint(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                address(this),
                                bytes32(salt),
                                keccak256(
                                    abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(implementation, ""))
                                )
                            )
                        )
                    )
                )
            );
    }
}
