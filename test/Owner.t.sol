// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "./utils/BaseCollection.t.sol";
import "./utils/Digests.sol";

contract OwnerTest is BaseCollection {
    event ProposerFeeUpdated(uint8 proposerFee);
    event SnapshotFeeUpdated(uint8 snapshotFee);
    event SnapshotOwnerUpdated(address snapshotOwner);
    event SnapshotTreasuryUpdated(address snapshotTreasury);
    event PowerSwitchUpdated(bool enabled);
    error InvalidFee(uint8 proposerFee);
    error CallerIsNotSnapshot();
    error PowerIsOff();

    function setUp() public virtual override {
        super.setUp();
        vm.stopPrank();
    }

    function test_Owner() public {
        assertEq(collection.owner(), address(this));
    }

    function test_SetMaxSupply() public {
        uint128 newSupply = 1337;
        vm.expectEmit(true, true, true, true);
        emit MaxSupplyUpdated(newSupply);
        collection.setMaxSupply(newSupply);

        // mint them and check
    }

    function test_UnauthorizedSetMaxSupply() public {
        uint128 newSupply = 1337;
        vm.prank(address(0xabcde));
        vm.expectRevert("Ownable: caller is not the owner");
        collection.setMaxSupply(newSupply);
    }

    function test_SetMintPrice() public {
        uint128 newPrice = 1337;
        vm.expectEmit(true, true, true, true);
        emit MintPriceUpdated(newPrice);
        collection.setMintPrice(newPrice);

        // todo: mint them and check
    }

    function test_UnauthorizedSetMintPrice() public {
        uint128 newMintPrice = 1337;
        vm.prank(address(0xabcde));
        vm.expectRevert("Ownable: caller is not the owner");
        collection.setMintPrice(newMintPrice);
    }

    function test_SetProposerFee() public {
        uint8 newProposerFee = 2 * proposerFee;
        vm.expectEmit(true, true, true, true);
        emit ProposerFeeUpdated(newProposerFee);
        collection.setProposerFee(newProposerFee);

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

        // Proceed to claims
        vm.prank(snapshotTreasury);
        collection.snapshotClaim();
        vm.prank(spaceTreasury);
        collection.spaceClaim();

        uint256 proposerRevenue = (mintPrice * newProposerFee) / 100;
        uint256 snapshotRevenue = ((mintPrice - proposerRevenue) * snapshotFee) / 100;
        // The space treasury received the mintPrice minus the proposer cut and the snapshot cut.
        assertEq(WETH.balanceOf(spaceTreasury), mintPrice - proposerRevenue - snapshotRevenue);

        // Snapshot received their revenue.
        assertEq(WETH.balanceOf(snapshotTreasury), snapshotRevenue);

        // The proposer received the proposer cut.
        assertEq(WETH.balanceOf(proposer), proposerRevenue);
    }

    function test_SetProposerFeeMax() public {
        uint8 newProposerFee = 100;
        vm.expectEmit(true, true, true, true);
        emit ProposerFeeUpdated(newProposerFee);
        collection.setProposerFee(newProposerFee);

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

        // Proceed to claims
        vm.prank(snapshotTreasury);
        collection.snapshotClaim();
        vm.prank(spaceTreasury);
        collection.spaceClaim();

        // The space treasury didn't receive anything.
        assertEq(WETH.balanceOf(spaceTreasury), 0);

        // Snaphsot didn't receive anything either because the proposer took everything.
        assertEq(WETH.balanceOf(snapshotTreasury), 0);

        // The proposer received the proposer cut.
        assertEq(WETH.balanceOf(proposer), mintPrice);
    }

    function test_SetProposerFeeMin() public {
        uint8 newProposerFee = 0;
        vm.expectEmit(true, true, true, true);
        emit ProposerFeeUpdated(newProposerFee);
        collection.setProposerFee(newProposerFee);

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

        // Proceed to claims
        vm.prank(snapshotTreasury);
        collection.snapshotClaim();
        vm.prank(spaceTreasury);
        collection.spaceClaim();

        uint256 snapshotRevenue = (mintPrice * snapshotFee) / 100;
        // The space treasury received the mintPrice minus the snapshot cut.
        assertEq(WETH.balanceOf(spaceTreasury), mintPrice - snapshotRevenue);

        // Snapshot received their revenue.
        assertEq(WETH.balanceOf(snapshotTreasury), snapshotRevenue);

        // The proposer received the proposer cut.
        assertEq(WETH.balanceOf(proposer), 0);
    }

    function test_SetProposerFeeInvalid() public {
        uint8 newProposerFee = 101;
        vm.expectRevert(abi.encodeWithSelector(InvalidFee.selector, newProposerFee));
        collection.setProposerFee(newProposerFee);
    }

    function test_SetProposerFeeUnauthorized() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0x123456789));
        collection.setProposerFee(50);
    }

    function test_SetProposerAndSnapshotFeesMin() public {
        uint8 newProposerFee = 0;
        uint8 newSnapshotFee = 0;
        vm.expectEmit(true, true, true, true);
        emit ProposerFeeUpdated(newProposerFee);
        collection.setProposerFee(newProposerFee);

        vm.expectEmit(true, true, true, true);
        emit SnapshotFeeUpdated(newSnapshotFee);
        vm.prank(snapshotOwner);
        collection.setSnapshotFee(newSnapshotFee);

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

        // Proceed to claims
        vm.prank(snapshotTreasury);
        collection.snapshotClaim();
        vm.prank(spaceTreasury);
        collection.spaceClaim();

        // The space treasury received everything.
        assertEq(WETH.balanceOf(spaceTreasury), mintPrice);

        // Snapshot didn't receive anything.
        assertEq(WETH.balanceOf(snapshotTreasury), 0);

        // The proposer didn't receive anything.
        assertEq(WETH.balanceOf(proposer), 0);
    }

    function test_SetSnapshotFee() public {
        uint8 newSnapshotFee = 42;
        vm.expectEmit(true, true, true, true);
        emit SnapshotFeeUpdated(newSnapshotFee);
        vm.prank(snapshotOwner);
        collection.setSnapshotFee(newSnapshotFee);

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

        // Proceed to claims
        vm.prank(snapshotTreasury);
        collection.snapshotClaim();
        vm.prank(spaceTreasury);
        collection.spaceClaim();

        uint256 proposerRevenue = (mintPrice * proposerFee) / 100;
        uint256 snapshotRevenue = ((mintPrice - proposerRevenue) * newSnapshotFee) / 100;
        // The space treasury received the mintPrice minus the proposer cut and the snapshot cut.
        assertEq(WETH.balanceOf(spaceTreasury), mintPrice - proposerRevenue - snapshotRevenue);

        // Snapshot received their revenue.
        assertEq(WETH.balanceOf(snapshotTreasury), snapshotRevenue);

        // The proposer received the proposer cut.
        assertEq(WETH.balanceOf(proposer), proposerRevenue);
    }

    function test_SetSnapshotFeeMax() public {
        uint8 newSnapshotFee = 100;
        vm.expectEmit(true, true, true, true);
        emit SnapshotFeeUpdated(newSnapshotFee);
        vm.prank(snapshotOwner);
        collection.setSnapshotFee(newSnapshotFee);

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

        // Proceed to claims
        vm.prank(snapshotTreasury);
        collection.snapshotClaim();
        vm.prank(spaceTreasury);
        collection.spaceClaim();

        uint256 proposerRevenue = (mintPrice * proposerFee) / 100;
        uint256 snapshotRevenue = ((mintPrice - proposerRevenue) * newSnapshotFee) / 100;
        // The space treasury didn't receive anything.
        assertEq(WETH.balanceOf(spaceTreasury), 0);

        // Snapshot received their revenue.
        assertEq(WETH.balanceOf(snapshotTreasury), snapshotRevenue);

        // The proposer received the proposer cut.
        assertEq(WETH.balanceOf(proposer), proposerRevenue);
    }

    function test_SetSnapshotFeeMin() public {
        uint8 newSnapshotFee = 0;
        vm.expectEmit(true, true, true, true);
        emit SnapshotFeeUpdated(newSnapshotFee);
        vm.prank(snapshotOwner);
        collection.setSnapshotFee(newSnapshotFee);

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

        // Proceed to claims
        vm.prank(snapshotTreasury);
        collection.snapshotClaim();
        vm.prank(spaceTreasury);
        collection.spaceClaim();

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
        vm.expectRevert(abi.encodeWithSelector(InvalidFee.selector, newSnapshotFee));
        vm.prank(snapshotOwner);
        collection.setSnapshotFee(newSnapshotFee);
    }

    function test_SetSnapshotFeeUnauthorized() public {
        vm.expectRevert(CallerIsNotSnapshot.selector);
        vm.prank(address(0x123456789));
        collection.setSnapshotFee(50);
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
        collection.setSnapshotTreasury(newTreasury);

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

        // Proceed to claims
        vm.prank(newTreasury);
        collection.snapshotClaim();
        vm.prank(spaceTreasury);
        collection.spaceClaim();

        uint256 proposerRevenue = (mintPrice * proposerFee) / 100;
        uint256 snapshotRevenue = ((mintPrice - proposerRevenue) * snapshotFee) / 100;
        // Assert the new treasury has received the money.
        assertEq(WETH.balanceOf(newTreasury), snapshotRevenue);
        // Assert the old treasury didn't receive anything.
        assertEq(WETH.balanceOf(snapshotTreasury), 0);
    }

    function test_SetSnapshotTreasuryUnauthorized() public {
        address newTreasury = address(0x9876);

        vm.expectRevert(CallerIsNotSnapshot.selector);
        collection.setSnapshotTreasury(newTreasury);
    }

    function test_SetPowerSwitchOff() public {
        collection.setPowerSwitch(false);

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
        vm.expectRevert(abi.encodeWithSelector(PowerIsOff.selector));
        vm.prank(recipient);
        collection.mint(proposer, proposalId, salt, v, r, s);
    }

    function test_SetPowerSwitchOffAndOn() public {
        vm.expectEmit(true, true, true, true);
        emit PowerSwitchUpdated(false);
        collection.setPowerSwitch(false);

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
        vm.expectRevert(abi.encodeWithSelector(PowerIsOff.selector));
        vm.prank(recipient);
        collection.mint(proposer, proposalId, salt, v, r, s);

        vm.expectEmit(true, true, true, true);
        emit PowerSwitchUpdated(true);
        collection.setPowerSwitch(true);
        // This time, it shouldn't revert!
        vm.prank(recipient);
        collection.mint(proposer, proposalId, salt, v, r, s);
    }
}
