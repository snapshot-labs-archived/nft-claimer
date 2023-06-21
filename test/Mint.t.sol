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

    function test_AMint() public {
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

        uint256 proposerRevenue = (mintPrice * proposerFee) / 100;
        uint256 snapshotRevenue = (mintPrice * snapshotFee) / 100;

        // The space treasury received the mintPrice minus the proposer cut and the snapshot cut
        assertEq(WETH.balanceOf(spaceTreasury), mintPrice - proposerRevenue - snapshotRevenue);
        // The proposer received the proposer cut.
        assertEq(WETH.balanceOf(proposer), proposerRevenue);
        // Snapshot receive the snapshot cut.
        assertEq(WETH.balanceOf(snapshotTreasury), snapshotRevenue);
    }

    function test_MintSaltAlreadyUsed() public {
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

        // Ensure the NFT has been minted
        assertEq(collection.balanceOf(recipient, proposalId), 1);

        vm.expectRevert(SaltAlreadyUsed.selector);
        collection.mint(proposer, proposalId, salt, v, r, s);
    }

    function test_MintInvalidSignature() public {
        bytes32 digest = Digests._getMintDigest(
            NAME,
            VERSION,
            address(collection),
            proposer,
            recipient,
            proposalId,
            salt + 1
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        vm.expectRevert(InvalidSignature.selector);
        collection.mint(proposer, proposalId, salt, v, r, s);

        assertEq(collection.balanceOf(recipient, proposalId), 0);
    }

    function test_MintMaxSupply() public {
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes32 digest;

        for (uint256 i = 0; i < maxSupply; i++) {
            salt += 1;
            digest = Digests._getMintDigest(NAME, VERSION, address(collection), proposer, recipient, proposalId, salt);

            (v, r, s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
            collection.mint(proposer, proposalId, salt, v, r, s);
        }

        salt += 1;
        digest = Digests._getMintDigest(NAME, VERSION, address(collection), proposer, recipient, proposalId, salt);

        (v, r, s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        vm.expectRevert(MaxSupplyReached.selector);
        collection.mint(proposer, proposalId, salt, v, r, s);
    }

    function test_MintInvalidMessageSender() public {
        bytes32 digest = Digests._getMintDigest(
            NAME,
            VERSION,
            address(collection),
            proposer,
            recipient,
            proposalId,
            salt + 1
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        vm.stopPrank();
        vm.prank(address(this)); // Invalid Message Sender!
        vm.expectRevert(InvalidSignature.selector);
        collection.mint(proposer, proposalId, salt, v, r, s);
    }
}
