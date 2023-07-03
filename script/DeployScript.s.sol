// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { Script } from "forge-std/Script.sol";
import { SpaceCollectionFactory } from "../src/SpaceCollectionFactory.sol";
import { SpaceCollection } from "../src/SpaceCollection.sol";
import { Digests } from "../test/utils/Digests.sol";
import { NO_UPDATE_U8, NO_UPDATE_ADDRESS } from "../test/utils/BaseCollection.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// solhint-disable-next-line max-states-count
contract DeployScript is Script {
    string constant FACTORY_NAME = "SpaceCollectionFactory";
    string constant FACTORY_VERSION = "0.1";
    string constant COLLECTION_NAME = "TestDAO";
    string constant COLLECTION_VERSION = "0.1";

    // Goerli WETH
    IERC20 private constant WETH = IERC20(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6);

    function run() public {
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
            COLLECTION_NAME,
            COLLECTION_VERSION,
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

        SpaceCollection collection = SpaceCollection(_predictProxyAddress(address(factory), implem, salt));
        WETH.approve(address(collection), mintPrice * 3); // Should mint three times

        uint256 proposalId = 1;
        _mint_one(collection, deployerAddr, deployerAddr, proposalId, salt);

        salt += 1;
        address[] memory proposers = new address[](2);
        proposers[0] = deployerAddr;
        proposers[1] = deployerAddr;

        uint256[] memory proposalIds = new uint256[](2);
        proposalIds[0] = 2;
        proposalIds[1] = 3;

        _mint_batch(collection, proposers, deployerAddr, proposalIds, salt);

        factory.updateFactorySettings(NO_UPDATE_U8, NO_UPDATE_ADDRESS, NO_UPDATE_ADDRESS, verifiedSigner);
        factory.transferOwnership(verifiedSigner);

        vm.stopBroadcast();
    }

    function _mint_one(
        SpaceCollection collection,
        address proposer,
        address recipient,
        uint256 proposalId,
        uint256 salt
    ) internal {
        bytes32 digest = Digests._getMintDigest(
            COLLECTION_NAME,
            COLLECTION_VERSION,
            address(collection),
            proposer,
            recipient,
            proposalId,
            salt
        );

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(deployerPrivateKey, digest);

        collection.mint(proposer, proposalId, salt, v, r, s);
    }

    function _mint_batch(
        SpaceCollection collection,
        address[] memory proposers,
        address recipient,
        uint256[] memory proposalIds,
        uint256 salt
    ) internal {
        bytes32 digest = Digests._getMintBatchDigest(
            COLLECTION_NAME,
            COLLECTION_VERSION,
            address(collection),
            proposers,
            recipient,
            proposalIds,
            salt
        );

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(deployerPrivateKey, digest);

        collection.mintBatch(proposers, proposalIds, salt, v, r, s);
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
