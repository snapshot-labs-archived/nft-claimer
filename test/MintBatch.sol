// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import { BaseCollection } from "./utils/BaseCollection.t.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";
import { GasSnapshot } from "forge-gas-snapshot/GasSnapshot.sol";
import { Digests } from "./utils/Digests.sol";

contract SpaceCollectionTest is BaseCollection, GasSnapshot {
    address[] proposers = new address[](5);
    uint256[] proposalIds = new uint256[](5);

    function setUp() public override {
        super.setUp();

        // Fill up the proposers and proposalIds

        proposers[0] = address(0x20);
        proposalIds[0] = 0;

        proposers[1] = address(0x21);
        proposalIds[1] = 1;

        proposers[2] = address(0x22);
        proposalIds[2] = 2;

        proposers[3] = address(0x23);
        proposalIds[3] = 3;

        proposers[4] = address(0x24);
        proposalIds[4] = 4;
    }

    function test_MintBatch() public {
        bytes32 digest = Digests._getMintBatchDigest(
            NAME,
            VERSION,
            address(collection),
            proposers,
            recipient,
            proposalIds,
            salt
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        collection.mintBatch(proposers, proposalIds, salt, v, r, s);

        // The recipient only paid (`mintPrice * proposers.length`) and no more.
        assertEq(WETH.balanceOf(recipient), INITIAL_WETH - (mintPrice * proposers.length));

        uint256 totalProposerRevenue;
        uint256 totalSnapshotRevenue;
        for (uint256 i = 0; i < proposers.length; i++) {
            assertEq(collection.balanceOf(recipient, proposalIds[i]), 1);
            uint256 proposerRevenue = (mintPrice * proposerFee) / 100;
            uint256 snapshotRevenue = (mintPrice * snapshotFee) / 100;
            totalProposerRevenue += proposerRevenue;
            totalSnapshotRevenue += snapshotRevenue;
        }

        // The space treasury received the mintPrice minus the proposer cut and the snapshot cut
        assertEq(
            WETH.balanceOf(spaceTreasury),
            mintPrice * proposers.length - totalProposerRevenue - totalSnapshotRevenue
        );

        // The proposers received their proposer cut.
        for (uint256 i = 0; i < proposers.length; i++) {
            assertEq(WETH.balanceOf(proposers[i]), (mintPrice * proposerFee) / 100);
        }

        // Snapshot received the snapshot cut.
        assertEq(WETH.balanceOf(snapshotTreasury), totalSnapshotRevenue);
    }

    // function test_MintBatchMaxSupply() public {
    //     address[] memory newProposers = new address[](maxSupply + 1);
    //     uint256[] memory newProposalIds = new uint256[](maxSupply + 1);

    //     for (uint256 i = 0; i < newProposalIds.length; i++) {
    //         newProposers[i] = address(uint160(i + 1));
    //         newProposalIds[i] = i; // Minting on the same proposal
    //     }

    //     bytes32 digest = Digests._getMintBatchDigest(
    //         NAME,
    //         VERSION,
    //         address(collection),
    //         newProposers,
    //         recipient,
    //         newProposalIds,
    //         salt
    //     );

    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
    //     collection.mintBatch(newProposers, newProposalIds, salt, v, r, s);

    //     // Check everything got minted properly
    //     for (uint256 i = 0; i < maxSupply; i++) {
    //         assertEq(collection.balanceOf(newProposers[i], newProposalIds[i]), 1);
    //     }

    //     // The recipient only paid (`mintPrice * proposers.length`) and no more.
    //     assertEq(WETH.balanceOf(recipient), INITIAL_WETH - (mintPrice * newProposers.length));

    //     uint256 totalProposerRevenue;
    //     uint256 totalSnapshotRevenue;
    //     for (uint256 i = 0; i < newProposers.length; i++) {
    //         console2.log("inside");
    //         assertEq(collection.balanceOf(recipient, newProposalIds[i]), 1);
    //         uint256 proposerRevenue = (mintPrice * proposerFee) / 100;
    //         uint256 snapshotRevenue = (mintPrice * snapshotFee) / 100;
    //         totalProposerRevenue += proposerRevenue;
    //         totalSnapshotRevenue += snapshotRevenue;
    //     }
    //     console2.log("out");

    //     // The space treasury received the mintPrice minus the proposer cut and the snapshot cut
    //     assertEq(
    //         WETH.balanceOf(spaceTreasury),
    //         mintPrice * newProposers.length - totalProposerRevenue - totalSnapshotRevenue
    //     );

    //     // The proposers received their proposer cut.
    //     for (uint256 i = 0; i < newProposers.length; i++) {
    //         console2.log("proposers");
    //         assertEq(WETH.balanceOf(newProposers[i]), (mintPrice * proposerFee) / 100);
    //     }
    //     console2.log("total");

    //     // Snapshot received the snapshot cut.
    //     assertEq(WETH.balanceOf(snapshotTreasury), totalSnapshotRevenue);
    // }
}
