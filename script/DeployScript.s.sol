// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { Script } from "forge-std/Script.sol";
import { SpaceCollectionFactory } from "../src/SpaceCollectionFactory.sol";
import { SpaceCollection } from "../src/SpaceCollection.sol";
import { Digests } from "../test/utils/Digests.sol";

// solhint-disable-next-line max-states-count
contract DeployScript is Script {
    SpaceCollection public collection;
    function run() public {
        string memory FACTORY_NAME = "SpaceCollectionFactory";
        string memory FACTORY_VERSION = "0.1";
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddr = vm.addr(deployerPrivateKey);
        string memory spaceId = "spaceId";
        uint8 proposerFee = 10;
        uint8 snapshotFee = 1;
        address snapshotOwner = deployerAddr;
        address snapshotTreasury = deployerAddr;
        address trustedBackend = deployerAddr;

        vm.startBroadcast(deployerPrivateKey);
        uint256 salt = uint256(bytes32(keccak256(abi.encodePacked("salt"))));

        uint128 maxSupply = 10;

        // 0.1 WETH
        uint256 mintPrice = 0;
        address spaceTreasury = address(deployerAddr);
        address spaceOwner = deployerAddr;
        // bytes4(keccak256(bytes(
        // "initialize(string,string,string,uint128,uint256,uint8,address,address,uint8,address,address,address)"
        // )))
        bytes4 SPACE_INITIALIZE_SELECTOR = 0xd5716032;
        bytes memory initializer = abi.encodeWithSelector(
            SPACE_INITIALIZE_SELECTOR,
            "TestDAO",
            "0.1",
            spaceId,
            maxSupply,
            mintPrice,
            proposerFee,
            spaceTreasury,
            spaceOwner
        );

        SpaceCollectionFactory factory = new SpaceCollectionFactory(
            snapshotFee,
            deployerAddr,
            snapshotOwner,
            snapshotTreasury
        );
        address implem = address(new SpaceCollection());

        bytes32 digest = Digests._getDeployDigest(
            FACTORY_NAME,
            FACTORY_VERSION,
            address(factory),
            implem,
            initializer,
            salt
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(deployerPrivateKey, digest);

        factory.deployProxy(implem, initializer, salt, v, r, s);

        collection = SpaceCollection(factory.predictProxyAddress(implem, salt));
        uint256 new_salt = uint256(bytes32(keccak256(abi.encodePacked("new_salt"))));
        uint256 proposalId = 27;
        bytes32 digest_mint = Digests._getMintDigest(
            "TestDAO",
            "0.1",
            address(collection),
            deployerAddr,
            deployerAddr,
            proposalId,
            new_salt
        );

        (uint8 new_v, bytes32 new_r, bytes32 new_s) = vm.sign(deployerPrivateKey, digest_mint);
        collection.mint(deployerAddr, proposalId, new_salt, new_v, new_r, new_s);

        collection.setMintPrice(100000000000000000);

        factory.setTrustedBackend(trustedBackend);
        factory.transferOwnership(trustedBackend);

        vm.stopBroadcast();
    }
}
