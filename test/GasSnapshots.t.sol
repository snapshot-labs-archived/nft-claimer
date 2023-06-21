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

    function test_GasSnapshots() public {
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
        snapStart("FirstMintFirstCollection");
        collection.mint(proposer, proposalId, salt, v, r, s);
        snapEnd();

        assertEq(collection.balanceOf(recipient, proposalId), 1);

        salt += 1; // Increase salt
        digest = Digests._getMintDigest(NAME, VERSION, address(collection), proposer, recipient, proposalId, salt);
        (v, r, s) = vm.sign(SIGNER_PRIVATE_KEY, digest);

        snapStart("SecondMintSameAddressFirstCollection");
        collection.mint(proposer, proposalId, salt, v, r, s);
        snapEnd();

        assertEq(collection.balanceOf(recipient, proposalId), 2);

        address newRecipient = address(0x4567); // Change recipient
        digest = Digests._getMintDigest(NAME, VERSION, address(collection), proposer, newRecipient, proposalId, salt);
        (v, r, s) = vm.sign(SIGNER_PRIVATE_KEY, digest);

        WETH.transfer(newRecipient, mintPrice * 2);
        vm.stopPrank();
        vm.startPrank(newRecipient);
        WETH.approve(address(collection), mintPrice * 2);

        snapStart("SecondMintDifferentAddressFirstCollection");
        collection.mint(proposer, proposalId, salt, v, r, s);
        snapEnd();

        assertEq(collection.balanceOf(newRecipient, proposalId), 1);

        // -- Switch to second collection
        vm.stopPrank();
        vm.startPrank(recipient);
        proposalId += 1;
        salt += 1;

        digest = Digests._getMintDigest(NAME, VERSION, address(collection), proposer, recipient, proposalId, salt);

        (v, r, s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        snapStart("FirstMintSecondCollection");
        collection.mint(proposer, proposalId, salt, v, r, s);
        snapEnd();

        assertEq(collection.balanceOf(recipient, proposalId), 1);
    }
}
