// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { Script } from "forge-std/Script.sol";
import { SpaceCollectionFactory } from "../src/SpaceCollectionFactory.sol";
import { SpaceCollection } from "../src/SpaceCollection.sol";
import { Digests } from "../test/utils/Digests.sol";

// solhint-disable-next-line max-states-count
contract DeployScript is Script {
    function run() public {
        string memory FACTORY_NAME = "SpaceCollectionFactory";
        string memory FACTORY_VERSION = "0.1";
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddr = vm.addr(deployerPrivateKey);
        uint8 proposerFee = 10;
        uint8 snapshotFee = 1;
        address snapshotOwner = deployerAddr;
        address snapshotTreasury = deployerAddr;
        address verifiedSigner = 0xE67e3A73C5b1ff82fD9Bd08f869d94B249d79e2F;

        vm.startBroadcast(deployerPrivateKey);
        uint256 salt = uint256(bytes32(keccak256(abi.encodePacked("salt"))));

        uint128 maxSupply = 10;

        // 0.1 WETH
        uint256 mintPrice = 100000000000000000;
        address spaceTreasury = address(0x5EF29cf961cf3Fc02551B9BdaDAa4418c446c5dd);
        address spaceOwner = spaceTreasury;
        // bytes4(keccak256(bytes(
        // "initialize(string,string,uint128,uint256,uint8,address,address,uint8,address,address,address)"
        // )))
        bytes4 SPACE_INITIALIZE_SELECTOR = 0x977b0efb;
        bytes memory initializer = abi.encodeWithSelector(
            SPACE_INITIALIZE_SELECTOR,
            "TestDAO",
            "0.1",
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

        factory.setVerifiedSigner(verifiedSigner);
        factory.transferOwnership(verifiedSigner);

        vm.stopBroadcast();
    }
}
