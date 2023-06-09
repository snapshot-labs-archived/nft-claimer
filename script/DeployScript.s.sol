// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { Script } from "forge-std/Script.sol";
import { ProxyFactory } from "../src/ProxyFactory.sol";
import { SpaceCollection } from "../src/SpaceCollection.sol";
import { Digests } from "../test/utils/Digests.sol";

// solhint-disable-next-line max-states-count
contract DeployScript is Script {
    function run() public {
        string memory PROXY_NAME = "ProxySpaceCollectionFactory";
        string memory PROXY_VERSION = "1.0";
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddr = vm.addr(deployerPrivateKey);
        address trustedBackend = deployerAddr;
        string memory spaceId = "spaceId";
        uint8 proposerFee = 10;
        uint8 snapshotFee = 1;
        address snapshotOwner = deployerAddr;
        address snapshotTreasury = deployerAddr;
        // address trustedBackend = 0xE67e3A73C5b1ff82fD9Bd08f869d94B249d79e2F;

        vm.startBroadcast(deployerPrivateKey);
        uint256 salt = uint256(bytes32(keccak256(abi.encodePacked("salt"))));

        uint128 maxSupply = 10;

        // 0.1 WETH
        uint256 mintPrice = 100000000000000000;
        address spaceTreasury = address(0x5EF29cf961cf3Fc02551B9BdaDAa4418c446c5dd);
        bytes memory initializer = abi.encodeWithSelector(
            SpaceCollection.initialize.selector,
            "TestTrustedBackend",
            "0.1",
            spaceId,
            maxSupply,
            mintPrice,
            proposerFee,
            snapshotFee,
            trustedBackend,
            snapshotOwner,
            snapshotTreasury,
            spaceTreasury
        );

        ProxyFactory factory = new ProxyFactory(snapshotFee, deployerAddr, snapshotOwner, snapshotTreasury);
        address implem = address(new SpaceCollection());

        bytes32 digest = Digests._getDeployDigest(
            PROXY_NAME,
            PROXY_VERSION,
            address(factory),
            implem,
            initializer,
            salt
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(deployerPrivateKey, digest);

        factory.deployProxy(implem, initializer, salt, v, r, s);

        vm.stopBroadcast();
    }
}
