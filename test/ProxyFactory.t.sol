// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { Test } from "forge-std/Test.sol";
import { SpaceCollection } from "../src/SpaceCollection.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ProxyFactory } from "../src/ProxyFactory.sol";
import { IProxyFactoryEvents } from "../src/interfaces/factory/IProxyFactoryEvents.sol";
import { IProxyFactoryErrors } from "../src/interfaces/factory/IProxyFactoryErrors.sol";
import { Digests } from "./utils/Digests.sol";

// solhint-disable-next-line max-states-count
contract SpaceCollectionFactoryTest is Test, IProxyFactoryEvents, IProxyFactoryErrors {
    address public implem;
    ProxyFactory public factory;

    string PROXY_NAME = "ProxySpaceCollectionFactory";
    string PROXY_VERSION = "1.0";
    string COLLECTION_NAME = "NFT-CLAIMER";
    string COLLECTION_VERSION = "0.1";

    uint256 public constant SIGNER_PRIVATE_KEY = 1234;
    address public signerAddress;
    uint128 maxSupply = 10;
    uint256 mintPrice = 1;
    uint256 spaceId = 1337;
    address spaceTreasury = address(0xabcd);
    bytes32 salt = bytes32(keccak256(abi.encodePacked("random salt")));
    bytes initializer;

    function setUp() public {
        implem = address(new SpaceCollection());
        signerAddress = vm.addr(SIGNER_PRIVATE_KEY);
        factory = new ProxyFactory(signerAddress);
        initializer = abi.encodeWithSelector(
            SpaceCollection.initialize.selector,
            COLLECTION_NAME,
            COLLECTION_VERSION,
            spaceId,
            maxSupply,
            mintPrice,
            signerAddress,
            spaceTreasury
        );
    }

    function testCreateSpaceCollection() public {
        // Pre-computed address of the space (possible because of CREATE2 deployment)
        address collectionProxy = _predictProxyAddress(address(factory), implem, salt);

        bytes32 digest = Digests._getDeployDigest(
            PROXY_NAME,
            PROXY_VERSION,
            address(factory),
            implem,
            initializer,
            salt
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);

        vm.expectEmit(true, true, true, true);
        emit ProxyDeployed(address(implem), collectionProxy);
        factory.deployProxy(implem, initializer, salt, v, r, s);
    }

    function testCreateSpaceInvalidImplementation() public {
        bytes32 digest = Digests._getDeployDigest(
            PROXY_NAME,
            PROXY_VERSION,
            address(factory),
            address(0),
            initializer,
            salt
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);

        vm.expectRevert(InvalidImplementation.selector);
        factory.deployProxy(address(0), initializer, salt, v, r, s);

        digest = Digests._getDeployDigest(
            PROXY_NAME,
            PROXY_VERSION,
            address(factory),
            address(0x123),
            initializer,
            salt
        );
        (v, r, s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        vm.expectRevert(InvalidImplementation.selector);
        factory.deployProxy(address(0x123), initializer, salt, v, r, s);
    }

    function testCreateSpaceReusedSalt() public {
        bytes32 digest = Digests._getDeployDigest(
            PROXY_NAME,
            PROXY_VERSION,
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

    function testCreateSpaceReInitialize() public {
        bytes32 digest = Digests._getDeployDigest(
            PROXY_NAME,
            PROXY_VERSION,
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
            spaceId,
            maxSupply,
            mintPrice,
            signerAddress,
            spaceTreasury
        );
    }

    function testPredictProxyAddress() public {
        // Checking predictProxyAddress in the factory returns the same address as the helper in this test
        assertEq(
            address(factory.predictProxyAddress(implem, salt)),
            _predictProxyAddress(address(factory), implem, salt)
        );
    }

    function _predictProxyAddress(
        address _factory,
        address _implementation,
        bytes32 _salt
    ) internal pure returns (address) {
        return
            address(
                uint160(
                    uint(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                _factory,
                                _salt,
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
