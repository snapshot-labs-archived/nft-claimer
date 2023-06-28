// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "./utils/BaseCollection.sol";
import "./utils/Digests.sol";

contract OwnerTest is BaseCollection {
    function setUp() public virtual override {
        super.setUp();
        vm.stopPrank();
    }

    function test_Owner() public {
        assertEq(collection.owner(), address(this));
    }

    function test_SetSnapshotFee() public {
        uint8 newSnapshotFee = 42;
        vm.expectEmit(true, true, true, true);
        emit SnapshotFeeUpdated(newSnapshotFee);
        vm.prank(snapshotOwner);
        collection.updateSnapshotSettings(newSnapshotFee, NO_UPDATE_ADDRESS, NO_UPDATE_ADDRESS);

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
        vm.prank(recipient);
        collection.mint(proposer, proposalId, salt, v, r, s);

        assertEq(collection.balanceOf(recipient, proposalId), 1);

        // The recipient only paid `mintPrice` and no more.
        assertEq(WETH.balanceOf(recipient), INITIAL_WETH - mintPrice);

        uint256 proposerRevenue = (mintPrice * proposerFee) / 100;
        uint256 snapshotRevenue = (mintPrice * newSnapshotFee) / 100;
        // The space treasury received the mintPrice minus the proposer cut and the snapshot cut.
        assertEq(WETH.balanceOf(spaceTreasury), mintPrice - proposerRevenue - snapshotRevenue);

        // Snapshot received their revenue.
        assertEq(WETH.balanceOf(snapshotTreasury), snapshotRevenue);

        // The proposer received the proposer cut.
        assertEq(WETH.balanceOf(proposer), proposerRevenue);
    }

    function test_SetSnapshotFeeMax() public {
        uint8 newSnapshotFee = 100;

        collection.updateSettings(NO_UPDATE_U128, NO_UPDATE_U256, 0, NO_UPDATE_ADDRESS);

        vm.expectEmit(true, true, true, true);
        emit SnapshotFeeUpdated(newSnapshotFee);
        vm.prank(snapshotOwner);
        collection.updateSnapshotSettings(newSnapshotFee, NO_UPDATE_ADDRESS, NO_UPDATE_ADDRESS);

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
        vm.prank(recipient);
        collection.mint(proposer, proposalId, salt, v, r, s);

        assertEq(collection.balanceOf(recipient, proposalId), 1);

        // The recipient only paid `mintPrice` and no more.
        assertEq(WETH.balanceOf(recipient), INITIAL_WETH - mintPrice);

        uint256 snapshotRevenue = (mintPrice * newSnapshotFee) / 100;
        // The space treasury didn't receive anything.
        assertEq(WETH.balanceOf(spaceTreasury), 0);

        // Snapshot received their revenue.
        assertEq(WETH.balanceOf(snapshotTreasury), snapshotRevenue);

        // The proposer didn't receive anything.
        assertEq(WETH.balanceOf(proposer), 0);
    }

    function test_SetSnapshotFeeMin() public {
        uint8 newSnapshotFee = 0;
        vm.expectEmit(true, true, true, true);
        emit SnapshotFeeUpdated(newSnapshotFee);
        vm.prank(snapshotOwner);
        collection.updateSnapshotSettings(newSnapshotFee, NO_UPDATE_ADDRESS, NO_UPDATE_ADDRESS);

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
        vm.prank(recipient);
        collection.mint(proposer, proposalId, salt, v, r, s);

        assertEq(collection.balanceOf(recipient, proposalId), 1);

        // The recipient only paid `mintPrice` and no more.
        assertEq(WETH.balanceOf(recipient), INITIAL_WETH - mintPrice);

        uint256 proposerRevenue = (mintPrice * proposerFee) / 100;
        // The space treasury received the mintPrice minus the proposer cut.
        assertEq(WETH.balanceOf(spaceTreasury), mintPrice - proposerRevenue);

        // Snapshot didn't receive anything.
        assertEq(WETH.balanceOf(snapshotTreasury), 0);

        // The proposer received the proposer cut.
        assertEq(WETH.balanceOf(proposer), proposerRevenue);
    }

    function test_SetSnapshotFeeInvalid() public {
        uint8 newSnapshotFee = 101;
        vm.expectRevert(abi.encodeWithSelector(InvalidFee.selector));
        vm.prank(snapshotOwner);
        collection.updateSnapshotSettings(newSnapshotFee, NO_UPDATE_ADDRESS, NO_UPDATE_ADDRESS);
    }

    function test_SetSnapshotFeeInvalidWithProposerFee() public {
        uint8 newSnapshotFee = 101 - proposerFee;
        vm.expectRevert(InvalidFee.selector);
        vm.prank(snapshotOwner);
        collection.updateSnapshotSettings(newSnapshotFee, NO_UPDATE_ADDRESS, NO_UPDATE_ADDRESS);
    }

    function test_SetSnapshotFeeUnauthorized() public {
        vm.expectRevert(CallerIsNotSnapshot.selector);
        vm.prank(address(0x123456789));
        collection.updateSnapshotSettings(50, NO_UPDATE_ADDRESS, NO_UPDATE_ADDRESS);
    }

    function test_SetSnapshotOwner() public {
        vm.expectEmit(true, true, true, true);
        address newOwner = address(0x9876);

        emit SnapshotOwnerUpdated(newOwner);
        vm.prank(snapshotOwner);
        collection.setSnapshotOwner(newOwner);

        // Set it back to the original owner
        vm.expectEmit(true, true, true, true);
        emit SnapshotOwnerUpdated(snapshotOwner);
        vm.prank(newOwner);
        collection.setSnapshotOwner(snapshotOwner);
    }

    function test_SetSnapshotOwnerUnauthorized() public {
        address newOwner = address(0x9876);

        vm.expectRevert(CallerIsNotSnapshot.selector);
        collection.setSnapshotOwner(newOwner);
    }

    function test_SetSnapshotTreasury() public {
        address newTreasury = address(0x9876);
        vm.expectEmit(true, true, true, true);

        emit SnapshotTreasuryUpdated(newTreasury);
        vm.prank(snapshotOwner);
        collection.updateSnapshotSettings(NO_UPDATE_U8, newTreasury, NO_UPDATE_ADDRESS);

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
        vm.prank(recipient);
        collection.mint(proposer, proposalId, salt, v, r, s);

        uint256 snapshotRevenue = (mintPrice * snapshotFee) / 100;
        // Assert the new treasury has received the money.
        assertEq(WETH.balanceOf(newTreasury), snapshotRevenue);
        // Assert the old treasury didn't receive anything.
        assertEq(WETH.balanceOf(snapshotTreasury), 0);
    }

    function test_SetSnapshotTreasuryUnauthorized() public {
        address newTreasury = address(0x9876);

        vm.expectRevert(CallerIsNotSnapshot.selector);
        collection.updateSnapshotSettings(NO_UPDATE_U8, newTreasury, NO_UPDATE_ADDRESS);
    }

    function test_SetVerifiedSigner() public {
        uint256 newPrivKey = 5678;
        address newAddress = vm.addr(newPrivKey);

        vm.expectEmit(true, true, true, true);
        emit VerifiedSignerUpdated(newAddress);
        vm.prank(snapshotOwner);
        collection.updateSnapshotSettings(NO_UPDATE_U8, NO_UPDATE_ADDRESS, newAddress);

        bytes32 digest = Digests._getMintDigest(
            NAME,
            VERSION,
            address(collection),
            proposer,
            recipient,
            proposalId,
            salt
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(newPrivKey, digest);
        vm.prank(recipient);
        collection.mint(proposer, proposalId, salt, v, r, s);
    }

    function test_SetVerifiedSignerUnauthorized() public {
        address newVerifiedSigner = address(0x5678);
        vm.prank(address(0xabcde));
        vm.expectRevert(CallerIsNotSnapshot.selector);
        collection.updateSnapshotSettings(NO_UPDATE_U8, NO_UPDATE_ADDRESS, newVerifiedSigner);
    }

    function test_SetVerifiedSignerCannotBeZero() public {
        vm.prank(snapshotOwner);
        vm.expectRevert(AddressCannotBeZero.selector);
        collection.updateSnapshotSettings(NO_UPDATE_U8, NO_UPDATE_ADDRESS, address(0));
    }
}
