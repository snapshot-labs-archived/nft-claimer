// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ISpaceCollectionFactory } from "./interfaces/ISpaceCollectionFactory.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/// @title Space Collection Factory
/// @notice A contract to deploy and track ERC1967 proxies of a given implementation contract.
contract SpaceCollectionFactory is ISpaceCollectionFactory, Ownable, EIP712 {
    bytes32 private constant DEPLOY_TYPEHASH =
        keccak256("Deploy(address implementation,bytes initializer,uint256 salt)");

    address public trustedBackend;
    string constant NAME = "SpaceCollectionFactory";
    string constant VERSION = "0.1";
    address public snapshotOwner;
    address public snapshotTreasury;
    uint8 public snapshotFee;

    constructor(
        uint8 _snapshotFee,
        address _trustedBackend,
        address _snapshotOwner,
        address _snapshotTreasury
    ) EIP712(NAME, VERSION) {
        if (_trustedBackend == address(0)) revert AddressCannotBeZero();

        snapshotFee = _snapshotFee;
        trustedBackend = _trustedBackend;
        snapshotOwner = _snapshotOwner;
        snapshotTreasury = _snapshotTreasury;
    }

    /// @inheritdoc ISpaceCollectionFactory
    function getInitializer(bytes calldata initializer) public view returns (bytes memory) {
        // Extract selector
        bytes4 selector = initializer[0] |
            (bytes4(initializer[1]) >> 8) |
            (bytes4(initializer[2]) >> 16) |
            (bytes4(initializer[3]) >> 24);

        // Decode the `initializer`, after the first 4 bytes (using slice feature)!
        (
            string memory _name,
            string memory _version,
            uint128 _maxSupply,
            uint256 _mintPrice,
            uint8 _proposerFee,
            address _spaceTreasury,
            address _spaceOwner
        ) = abi.decode(initializer[4:], (string, string, uint128, uint256, uint8, address, address));

        // Re-encode it and add our data: `snapshotFee`, `trustedBackend`, `snapshotOwner`, and `snapshotTreasury`.
        bytes memory result = abi.encodeWithSelector(
            selector,
            _name,
            _version,
            _maxSupply,
            _mintPrice,
            _proposerFee,
            _spaceTreasury,
            _spaceOwner,
            snapshotFee,
            trustedBackend,
            snapshotOwner,
            snapshotTreasury
        );

        return result;
    }

    /// @inheritdoc ISpaceCollectionFactory
    function setTrustedBackend(address _trustedBackend) external onlyOwner {
        if (_trustedBackend == address(0)) revert AddressCannotBeZero();

        trustedBackend = _trustedBackend;
        emit TrustedBackendUpdated(_trustedBackend);
    }

    /// @inheritdoc ISpaceCollectionFactory
    function setSnapshotOwner(address _snapshotOwner) external onlyOwner {
        snapshotOwner = _snapshotOwner;
        emit SnapshotOwnerUpdated(_snapshotOwner);
    }

    /// @inheritdoc ISpaceCollectionFactory
    function setSnapshotTreasury(address _snapshotTreasury) external onlyOwner {
        snapshotTreasury = _snapshotTreasury;
        emit SnapshotTreasuryUpdated(_snapshotTreasury);
    }

    /// @inheritdoc ISpaceCollectionFactory
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

        // Decode the initializer
        initializer = this.getInitializer(initializer);

        if (implementation == address(0) || implementation.code.length == 0) revert InvalidImplementation();
        if (predictProxyAddress(implementation, salt).code.length > 0) revert SaltAlreadyUsed();
        address proxy = address(new ERC1967Proxy{ salt: bytes32(salt) }(implementation, ""));

        emit ProxyDeployed(implementation, proxy);

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, ) = proxy.call(initializer);
        if (!success) revert FailedInitialization();
    }

    /// @inheritdoc ISpaceCollectionFactory
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
