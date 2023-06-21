// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import { BaseCollection } from "./utils/BaseCollection.t.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";
import { GasSnapshot } from "forge-gas-snapshot/GasSnapshot.sol";
import { Digests } from "./utils/Digests.sol";

contract SpaceCollectionTest is BaseCollection, GasSnapshot {
    function setUp() public override {
        super.setUp();
    }

    function test_Claim() public {
        bytes32 digest = Digests._getMintDigest(
            NAME,
            VERSION,
            address(collection),
            proposer,
            recipient,
            proposalId,
            salt
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        collection.mint(proposer, proposalId, salt, v, r, s);

        assertEq(collection.balanceOf(recipient, proposalId), 1);
        // The recipient only paid `mintPrice` and no more.
        assertEq(WETH.balanceOf(recipient), INITIAL_WETH - mintPrice);

        vm.stopPrank();
        vm.prank(snapshotTreasury);
        collection.snapshotClaim();
        vm.prank(spaceTreasury);
        collection.spaceClaim();

        uint256 proposerRevenue = (mintPrice * proposerFee) / 100;
        uint256 snapshotRevenue = (mintPrice * snapshotFee) / 100;

        // The space treasury received the mintPrice minus the proposer cut and the snapshot cut
        assertEq(WETH.balanceOf(spaceTreasury), mintPrice - proposerRevenue - snapshotRevenue);
        // The proposer received the proposer cut.
        assertEq(WETH.balanceOf(proposer), proposerRevenue);
        // Snapshot receive the snapshot cut.
        assertEq(WETH.balanceOf(snapshotTreasury), snapshotRevenue);
    }

    function test_ClaimTwice() public {
        bytes32 digest = Digests._getMintDigest(
            NAME,
            VERSION,
            address(collection),
            proposer,
            recipient,
            proposalId,
            salt
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        collection.mint(proposer, proposalId, salt, v, r, s);

        assertEq(collection.balanceOf(recipient, proposalId), 1);
        // The recipient only paid `mintPrice` and no more.
        assertEq(WETH.balanceOf(recipient), INITIAL_WETH - mintPrice);

        vm.stopPrank();
        vm.prank(snapshotTreasury);
        collection.snapshotClaim();
        vm.prank(spaceTreasury);
        collection.spaceClaim();

        // Claim a second time and make sure no errors occur
        vm.prank(snapshotTreasury);
        collection.snapshotClaim();
        vm.prank(spaceTreasury);
        collection.spaceClaim();

        uint256 proposerRevenue = (mintPrice * proposerFee) / 100;
        uint256 snapshotRevenue = (mintPrice * snapshotFee) / 100;

        // The space treasury received the mintPrice minus the proposer cut and the snapshot cut
        assertEq(WETH.balanceOf(spaceTreasury), mintPrice - proposerRevenue - snapshotRevenue);
        // The proposer received the proposer cut.
        assertEq(WETH.balanceOf(proposer), proposerRevenue);
        // Snapshot receive the snapshot cut.
        assertEq(WETH.balanceOf(snapshotTreasury), snapshotRevenue);
    }

    function test_ClaimAfterLotsOfMints() public {
        uint256 spaceRevenue;
        uint256 snapshotRevenue;
        uint256 proposerRevenue;

        uint256 totalSpaceRevenue;
        uint256 totalSnapshotRevenue;
        uint256 totalProposerRevenue;

        _mint_once(proposer, recipient, proposalId, salt);
        proposerRevenue = (mintPrice * proposerFee) / 100;
        snapshotRevenue = (mintPrice * snapshotFee) / 100;
        spaceRevenue = mintPrice - proposerRevenue - snapshotRevenue;
        totalProposerRevenue += proposerRevenue;
        totalSnapshotRevenue += snapshotRevenue;
        totalSpaceRevenue += spaceRevenue;

        _mint_once(proposer, recipient, proposalId + 1, salt + 1);
        proposerRevenue = (mintPrice * proposerFee) / 100;
        snapshotRevenue = (mintPrice * snapshotFee) / 100;
        spaceRevenue = mintPrice - proposerRevenue - snapshotRevenue;
        totalProposerRevenue += proposerRevenue;
        totalSnapshotRevenue += snapshotRevenue;
        totalSpaceRevenue += spaceRevenue;

        // Change the fees
        snapshotFee += 1; // Increase snapshot fee by 1
        proposerFee += 1; // Increase proposer fee by 1
        vm.stopPrank();
        vm.prank(snapshotOwner);
        collection.setSnapshotFee(snapshotFee);
        vm.prank(address(this));
        collection.setProposerFee(proposerFee);

        vm.startPrank(recipient);
        _mint_once(proposer, recipient, proposalId, salt + 2); // Mint back on the first proposal
        proposerRevenue = (mintPrice * proposerFee) / 100;
        snapshotRevenue = (mintPrice * snapshotFee) / 100;
        spaceRevenue = mintPrice - proposerRevenue - snapshotRevenue;
        totalProposerRevenue += proposerRevenue;
        totalSnapshotRevenue += snapshotRevenue;
        totalSpaceRevenue += spaceRevenue;

        _mint_once(proposer, recipient, proposalId + 2, salt + 3); // Mint on a new proposal
        proposerRevenue = (mintPrice * proposerFee) / 100;
        snapshotRevenue = (mintPrice * snapshotFee) / 100;
        spaceRevenue = mintPrice - proposerRevenue - snapshotRevenue;
        totalProposerRevenue += proposerRevenue;
        totalSnapshotRevenue += snapshotRevenue;
        totalSpaceRevenue += spaceRevenue;

        // The recipient only paid `mintPrice * 4` and no more.
        assertEq(WETH.balanceOf(recipient), INITIAL_WETH - (mintPrice * 4));

        vm.stopPrank();
        vm.prank(snapshotTreasury);
        collection.snapshotClaim();
        vm.prank(spaceTreasury);
        collection.spaceClaim();

        assertEq(WETH.balanceOf(spaceTreasury), totalSpaceRevenue);
        assertEq(WETH.balanceOf(proposer), totalProposerRevenue);
        assertEq(WETH.balanceOf(snapshotTreasury), totalSnapshotRevenue);
    }

    function _mint_once(address proposer, address recipient, uint256 proposalId, uint256 salt) public {
        bytes32 digest = Digests._getMintDigest(
            NAME,
            VERSION,
            address(collection),
            proposer,
            recipient,
            proposalId,
            salt
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        collection.mint(proposer, proposalId, salt, v, r, s);
    }
}
