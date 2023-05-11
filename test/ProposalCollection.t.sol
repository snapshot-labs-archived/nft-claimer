// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import { BaseCollection } from "./utils/BaseCollection.t.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";
import { GasSnapshot } from "forge-gas-snapshot/GasSnapshot.sol";

contract ProposalCollectionTest is BaseCollection, GasSnapshot {
    function setUp() public override {
        super.setUp();
    }

    function test_Mint() public {
        bytes32 digest = _getDigest(recipient, proposalId, salt);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        snapStart("FirstMint");
        collection.mint(proposalId, salt, v, r, s);
        snapEnd();

        assertEq(collection.balanceOf(recipient, proposalId), 1);
        assertEq(WETH.balanceOf(recipient), INITIAL_WETH - mintPrice);
        assertEq(WETH.balanceOf(spaceTreasury), mintPrice);
    }

    function test_GasSnapshots() public {
        bytes32 digest = _getDigest(recipient, proposalId, salt);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        snapStart("FirstMint");
        collection.mint(proposalId, salt, v, r, s);
        snapEnd();

        assertEq(collection.balanceOf(recipient, proposalId), 1);

        salt += 1; // Increase salt
        digest = _getDigest(recipient, proposalId, salt);
        (v, r, s) = vm.sign(SIGNER_PRIVATE_KEY, digest);

        snapStart("SecondMintSameAddress");
        collection.mint(proposalId, salt, v, r, s);
        snapEnd();

        assertEq(collection.balanceOf(recipient, proposalId), 2);

        address newRecipient = address(0x4567); // Change recipient
        digest = _getDigest(newRecipient, proposalId, salt);
        (v, r, s) = vm.sign(SIGNER_PRIVATE_KEY, digest);

        WETH.transfer(newRecipient, mintPrice * 2);
        vm.stopPrank();
        vm.startPrank(newRecipient);
        WETH.approve(address(collection), mintPrice * 2);

        snapStart("SecondMintDifferentAddress");
        collection.mint(proposalId, salt, v, r, s);
        snapEnd();

        assertEq(collection.balanceOf(newRecipient, proposalId), 1);
    }

    function test_MintSaltAlreadyUsed() public {
        bytes32 digest = _getDigest(recipient, proposalId, salt);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        collection.mint(proposalId, salt, v, r, s);

        // Ensure the NFT has been minted
        assertEq(collection.balanceOf(recipient, proposalId), 1);

        vm.expectRevert(SaltAlreadyUsed.selector);
        collection.mint(proposalId, salt, v, r, s);
    }

    function test_MintInvalidSignature() public {
        bytes32 digest = _getDigest(recipient, proposalId, salt + 1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        vm.expectRevert(InvalidSignature.selector);
        collection.mint(proposalId, salt, v, r, s);

        assertEq(collection.balanceOf(recipient, proposalId), 0);
    }

    function test_MintMaxSupply() public {
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes32 digest;

        for (uint256 i = 0; i < maxSupply; i++) {
            salt += 1;
            digest = _getDigest(recipient, proposalId, salt);

            (v, r, s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
            collection.mint(proposalId, salt, v, r, s);
        }

        salt += 1;
        digest = _getDigest(recipient, proposalId, salt);

        (v, r, s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        vm.expectRevert(MaxSupplyReached.selector);
        collection.mint(proposalId, salt, v, r, s);
    }

    function test_MintInvalidMessageSender() public {
        bytes32 digest = _getDigest(recipient, proposalId, salt + 1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        vm.stopPrank();
        vm.prank(address(this));
        vm.expectRevert(InvalidSignature.selector);
        collection.mint(proposalId, salt, v, r, s);
    }
}
