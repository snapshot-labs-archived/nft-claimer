// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import { BaseCollection } from "./utils/BaseCollection.sol";
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
            proposalIds
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        collection.mintBatch(proposers, proposalIds, v, r, s);

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

    function test_MintBatchWithMaxSupplyReached() public {
        address[] memory newProposers = new address[](2);
        uint256[] memory newProposalIds = new uint256[](2);

        newProposers[0] = address(0xaaaaaaaaaaaaaa);
        newProposers[1] = address(0xbbbbbbbbbbbbbb);

        newProposalIds[0] = 1;
        newProposalIds[1] = 2;

        // mint everything on proposalIds 1 but do not mint anything on
        // proposalId 2. When we will call `mintBatch`, the mint on `proposalId == 1` should be
        // unsuccessful but the one on `proposalId == 2` should work fine.

        for (uint256 i = 0; i < maxSupply; i++) {
            address newMinter = address(uint160(i + 1));
            vm.stopPrank();
            vm.startPrank(newMinter);
            WETH.mint(newMinter, INITIAL_WETH);
            WETH.approve(address(collection), INITIAL_WETH);
            bytes32 digest = Digests._getMintDigest(
                NAME,
                VERSION,
                address(collection),
                newProposers[0],
                newMinter,
                newProposalIds[0]
            );

            (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
            collection.mint(newProposers[0], newProposalIds[0], v, r, s);
        }

        vm.stopPrank();
        vm.startPrank(recipient);

        bytes32 digest2 = Digests._getMintBatchDigest(
            NAME,
            VERSION,
            address(collection),
            newProposers,
            recipient,
            newProposalIds
        );

        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(SIGNER_PRIVATE_KEY, digest2);
        collection.mintBatch(newProposers, newProposalIds, v2, r2, s2);

        // No NFT for proposalIds[0].
        assertEq(collection.balanceOf(recipient, newProposalIds[0]), 0);
        // One NFT for proposalIds[1].
        assertEq(collection.balanceOf(recipient, newProposalIds[1]), 1);

        // The recipient only paid `mintPrice` and no more.
        assertEq(WETH.balanceOf(recipient), INITIAL_WETH - (mintPrice));

        // The space treasury received the mintPrice minus the proposer cut and the snapshot cut
        assertEq(
            WETH.balanceOf(spaceTreasury),
            (((mintPrice * (100 - proposerFee - snapshotFee)) / 100) * (1 + maxSupply))
        );

        // The proposers received their proposer cut.
        assertEq(WETH.balanceOf(newProposers[0]), ((mintPrice * proposerFee) / 100) * maxSupply);
        assertEq(WETH.balanceOf(newProposers[1]), (mintPrice * proposerFee) / 100);

        // Snapshot received the snapshot cut.
        assertEq(WETH.balanceOf(snapshotTreasury), ((mintPrice * snapshotFee) / 100) * (1 + maxSupply));
    }

    function test_MintBatchDupplicates() public {
        address[] memory newProposers = new address[](2);
        uint256[] memory newProposalIds = new uint256[](2);

        newProposers[0] = address(1);
        newProposers[1] = address(2);
        // Duplicates
        newProposalIds[0] = 1;
        newProposalIds[1] = 1;

        bytes32 digest = Digests._getMintBatchDigest(
            NAME,
            VERSION,
            address(collection),
            newProposers,
            recipient,
            newProposalIds
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        vm.expectRevert(UserAlreadyMinted.selector);
        collection.mintBatch(newProposers, newProposalIds, v, r, s);
    }
}
