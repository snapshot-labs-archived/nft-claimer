// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { Script } from "forge-std/Script.sol";
import { ProxyFactory } from "../src/ProxyFactory.sol";
import { SpaceCollection } from "../src/SpaceCollection.sol";

// solhint-disable-next-line max-states-count
contract DeployScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddr = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);
        bytes32 salt = keccak256(abi.encodePacked("salt"));
        uint8 v = 0;
        bytes32 r = keccak256(abi.encodePacked("r"));
        bytes32 s = keccak256(abi.encodePacked("s"));
        uint128 maxSupply = 10;

        // 0.1 WETH
        uint256 mintPrice = 100000000000000000;
        address spaceTreasury = address(0x5EF29cf961cf3Fc02551B9BdaDAa4418c446c5dd);
        bytes memory initializer = abi.encodeWithSelector(
            SpaceCollection.initialize.selector,
            "TEST123",
            "0.1",
            maxSupply,
            mintPrice,
            deployerAddr,
            spaceTreasury
        );

        ProxyFactory factory = new ProxyFactory(deployerAddr);
        address implem = address(new SpaceCollection());
        factory.deployProxy(implem, initializer, salt, v, r, s);

        vm.stopBroadcast();
    }
}
