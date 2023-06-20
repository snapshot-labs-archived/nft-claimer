// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { Test } from "forge-std/Test.sol";
import { SpaceCollection } from "../src/SpaceCollection.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { SpaceCollectionFactory } from "../src/SpaceCollectionFactory.sol";
import { ISpaceCollectionFactoryEvents } from "../src/interfaces/factory/ISpaceCollectionFactoryEvents.sol";
import { ISpaceCollectionFactoryErrors } from "../src/interfaces/factory/ISpaceCollectionFactoryErrors.sol";
import { Digests } from "./utils/Digests.sol";

// solhint-disable-next-line max-states-count
contract SpaceCollectionFactoryTest is Test, ISpaceCollectionFactoryEvents, ISpaceCollectionFactoryErrors {
    event TrustedBackendUpdated(address newTrustedBackend);

    error AddressCannotBeZero();

    address public implem;
    SpaceCollectionFactory public factory;

    string FACTORY_NAME = "SpaceCollectionFactory";
    string FACTORY_VERSION = "0.1";
    string COLLECTION_NAME = "TestDAO";
    string COLLECTION_VERSION = "0.1";

    uint256 public constant SIGNER_PRIVATE_KEY = 1234;
    address public signerAddress;
    uint128 maxSupply = 10;
    uint256 mintPrice = 1;
    uint8 proposerFee = 10;
    uint8 snapshotFee = 1;
    address snapshotOwner = address(0x1111);
    address snapshotTreasury = address(0x2222);
    address spaceTreasury = address(0x3333);
    address spaceOwner = address(this);
    uint256 salt = uint256(bytes32(keccak256(abi.encodePacked("random salt"))));
    // bytes4(keccak256(bytes(
    //      "initialize(string,string,uint128,uint256,uint8,address,address,uint8,address,address,address)"
    //  )))
    bytes4 public constant SPACE_INITIALIZE_SELECTOR = 0x977b0efb;
    bytes initializer;

    function setUp() public {
        implem = address(new SpaceCollection());
        signerAddress = vm.addr(SIGNER_PRIVATE_KEY);
        factory = new SpaceCollectionFactory(snapshotFee, signerAddress, snapshotOwner, snapshotTreasury);
        initializer = abi.encodeWithSelector(
            SPACE_INITIALIZE_SELECTOR,
            COLLECTION_NAME,
            COLLECTION_VERSION,
            maxSupply,
            mintPrice,
            proposerFee,
            spaceTreasury,
            spaceOwner
        );
    }

    function test_CreateSpaceCollection() public {
        // Pre-computed address of the space (possible because of CREATE2 deployment)
        address collectionProxy = _predictProxyAddress(address(factory), implem, salt);
        SpaceCollection collection = SpaceCollection(collectionProxy);

        bytes32 digest = Digests._getDeployDigest(
            FACTORY_NAME,
            FACTORY_VERSION,
            address(factory),
            implem,
            initializer,
            salt
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);

        vm.expectEmit(true, true, true, true);
        emit ProxyDeployed(address(implem), collectionProxy);
        factory.deployProxy(implem, initializer, salt, v, r, s);

        (uint8 _proposerFee, uint8 _snapshotFee) = collection.fees();

        // Ensure snapshotFee, trustedBackend, snapshotOwner, and snapshotTreasury have been set
        assertEq(_snapshotFee, snapshotFee);
        assertEq(collection.trustedBackend(), signerAddress);
        assertEq(collection.snapshotOwner(), snapshotOwner);
        assertEq(collection.snapshotTreasury(), snapshotTreasury);
    }

    function test_CreateSpaceInvalidImplementation() public {
        bytes32 digest = Digests._getDeployDigest(
            FACTORY_NAME,
            FACTORY_VERSION,
            address(factory),
            address(0),
            initializer,
            salt
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);

        vm.expectRevert(InvalidImplementation.selector);
        factory.deployProxy(address(0), initializer, salt, v, r, s);

        digest = Digests._getDeployDigest(
            FACTORY_NAME,
            FACTORY_VERSION,
            address(factory),
            address(0x123),
            initializer,
            salt
        );
        (v, r, s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        vm.expectRevert(InvalidImplementation.selector);
        factory.deployProxy(address(0x123), initializer, salt, v, r, s);
    }

    function test_CreateSpaceReusedSalt() public {
        bytes32 digest = Digests._getDeployDigest(
            FACTORY_NAME,
            FACTORY_VERSION,
            address(factory),
            address(implem),
            initializer,
            salt
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        factory.deployProxy(implem, initializer, salt, v, r, s);
        // Reusing the same salt should revert as the computed space address will be
        // the same as the first deployment.
        vm.expectRevert(abi.encodePacked(SaltAlreadyUsed.selector));
        factory.deployProxy(implem, initializer, salt, v, r, s);
    }

    function test_CreateSpaceReInitialize() public {
        bytes32 digest = Digests._getDeployDigest(
            FACTORY_NAME,
            FACTORY_VERSION,
            address(factory),
            address(implem),
            initializer,
            salt
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        factory.deployProxy(implem, initializer, salt, v, r, s);
        address collectionProxy = _predictProxyAddress(address(factory), address(implem), salt);

        // Initializing the space should revert as the space is already initialized
        vm.expectRevert("Initializable: contract is already initialized");
        SpaceCollection(collectionProxy).initialize(
            COLLECTION_NAME,
            COLLECTION_VERSION,
            maxSupply,
            mintPrice,
            proposerFee,
            spaceTreasury,
            spaceOwner,
            snapshotFee,
            signerAddress,
            snapshotOwner,
            snapshotTreasury
        );
    }

    function test_SetTrustedBackend() public {
        // Pre-computed address of the space (possible because of CREATE2 deployment)
        address collectionProxy = _predictProxyAddress(address(factory), implem, salt);

        uint256 newPrivKey = 5678;
        address newAddress = vm.addr(newPrivKey);
        vm.expectEmit(true, true, true, true);
        emit TrustedBackendUpdated(newAddress);
        factory.setTrustedBackend(newAddress);

        bytes32 digest = Digests._getDeployDigest(
            FACTORY_NAME,
            FACTORY_VERSION,
            address(factory),
            implem,
            initializer,
            salt
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(newPrivKey, digest);

        vm.expectEmit(true, true, true, true);
        emit ProxyDeployed(address(implem), collectionProxy);
        factory.deployProxy(implem, initializer, salt, v, r, s);
    }

    function test_SetTrustedBackendUnauthorized() public {
        uint256 newPrivKey = 5678;
        address newAddress = vm.addr(newPrivKey);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0xdeadbeef));
        factory.setTrustedBackend(newAddress);
    }

    function test_SetTrustedBackendCannotBeZero() public {
        vm.expectRevert(AddressCannotBeZero.selector);
        factory.setTrustedBackend(address(0));
    }

    function test_PredictProxyAddress() public {
        // Checking predictProxyAddress in the factory returns the same address as the helper in this test
        assertEq(
            address(factory.predictProxyAddress(implem, salt)),
            _predictProxyAddress(address(factory), implem, salt)
        );
    }

    function _predictProxyAddress(
        address _factory,
        address _implementation,
        uint256 _salt
    ) internal pure returns (address) {
        return
            address(
                uint160(
                    uint(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                _factory,
                                bytes32(_salt),
                                keccak256(
                                    abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(_implementation, ""))
                                )
                            )
                        )
                    )
                )
            );
    }
}
