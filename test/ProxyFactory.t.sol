// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { Test } from "forge-std/Test.sol";
import { SpaceCollection } from "../src/SpaceCollection.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ProxyFactory } from "../src/ProxyFactory.sol";
import { IProxyFactoryEvents } from "../src/interfaces/factory/IProxyFactoryEvents.sol";
import { IProxyFactoryErrors } from "../src/interfaces/factory/IProxyFactoryErrors.sol";

// solhint-disable-next-line max-states-count
contract SpaceCollectionFactoryTest is Test, IProxyFactoryEvents, IProxyFactoryErrors {
    SpaceCollection public implem;
    ProxyFactory public factory;

    string NAME = "NFT-CLAIMER";
    string VERSION = "0.1";

    address public signerAddress;
    uint128 maxSupply = 10;
    uint256 mintPrice = 1;
    address spaceTreasury = address(0xabcd);

    function setUp() public {
        implem = new SpaceCollection();
        factory = new ProxyFactory();
    }

    function testCreateSpaceCollection() public {
        bytes32 salt = bytes32(keccak256(abi.encodePacked("random salt")));
        // Pre-computed address of the space (possible because of CREATE2 deployment)
        address collectionProxy = _predictProxyAddress(address(factory), address(implem), salt);

        vm.expectEmit(true, true, true, true);
        emit ProxyDeployed(address(implem), collectionProxy);
        factory.deployProxy(
            address(implem),
            abi.encodeWithSelector(
                SpaceCollection.initialize.selector,
                NAME,
                VERSION,
                maxSupply,
                mintPrice,
                signerAddress,
                spaceTreasury
            ),
            salt
        );
    }

    function testCreateSpaceInvalidImplementation() public {
        bytes32 salt = bytes32(keccak256(abi.encodePacked("random salt")));

        vm.expectRevert(InvalidImplementation.selector);
        factory.deployProxy(
            address(0),
            abi.encodeWithSelector(
                SpaceCollection.initialize.selector,
                NAME,
                VERSION,
                maxSupply,
                mintPrice,
                signerAddress,
                spaceTreasury
            ),
            salt
        );

        vm.expectRevert(InvalidImplementation.selector);
        factory.deployProxy(
            address(0x123),
            abi.encodeWithSelector(
                SpaceCollection.initialize.selector,
                NAME,
                VERSION,
                maxSupply,
                mintPrice,
                signerAddress,
                spaceTreasury
            ),
            salt
        );
    }

    function testCreateSpaceReusedSalt() public {
        bytes32 salt = bytes32(keccak256(abi.encodePacked("random salt")));
        factory.deployProxy(
            address(implem),
            abi.encodeWithSelector(
                SpaceCollection.initialize.selector,
                NAME,
                VERSION,
                maxSupply,
                mintPrice,
                signerAddress,
                spaceTreasury
            ),
            salt
        );
        // Reusing the same salt should revert as the computed space address will be
        // the same as the first deployment.
        vm.expectRevert(abi.encodePacked(SaltAlreadyUsed.selector));
        factory.deployProxy(
            address(implem),
            abi.encodeWithSelector(
                SpaceCollection.initialize.selector,
                NAME,
                VERSION,
                maxSupply,
                mintPrice,
                signerAddress,
                spaceTreasury
            ),
            salt
        );
    }

    function testCreateSpaceReInitialize() public {
        bytes32 salt = bytes32(keccak256(abi.encodePacked("random salt")));
        factory.deployProxy(
            address(implem),
            abi.encodeWithSelector(
                SpaceCollection.initialize.selector,
                NAME,
                VERSION,
                maxSupply,
                mintPrice,
                signerAddress,
                spaceTreasury
            ),
            salt
        );
        address collectionProxy = _predictProxyAddress(address(factory), address(implem), salt);

        // Initializing the space should revert as the space is already initialized
        vm.expectRevert("Initializable: contract is already initialized");
        SpaceCollection(collectionProxy).initialize(NAME, VERSION, maxSupply, mintPrice, signerAddress, spaceTreasury);
    }

    function testPredictProxyAddress() public {
        bytes32 salt = bytes32(keccak256(abi.encodePacked("random salt")));
        // Checking predictProxyAddress in the factory returns the same address as the helper in this test
        assertEq(
            address(factory.predictProxyAddress(address(implem), salt)),
            _predictProxyAddress(address(factory), address(implem), salt)
        );
    }

    function _predictProxyAddress(
        address _factory,
        address implementation,
        bytes32 salt
    ) internal pure returns (address) {
        return
            address(
                uint160(
                    uint(
                        keccak256(
                            abi.encodePacked(
                                bytes1(0xff),
                                _factory,
                                salt,
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
