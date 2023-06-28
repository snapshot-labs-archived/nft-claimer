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

    function test_SetMaxSupply() public {
        uint128 newSupply = 1337;
        vm.expectEmit(true, true, true, true);
        emit MaxSupplyUpdated(newSupply);
        collection.updateSettings(newSupply, NO_UPDATE_U256, NO_UPDATE_U8, NO_UPDATE_ADDRESS);

        assertEq(collection.maxSupply(), newSupply);
    }

    function test_SetMaxSupplyZero() public {
        uint128 newSupply = 0;
        vm.expectRevert(SupplyCannotBeZero.selector);
        collection.updateSettings(newSupply, NO_UPDATE_U256, NO_UPDATE_U8, NO_UPDATE_ADDRESS);
    }

    function test_UnauthorizedSetMaxSupply() public {
        uint128 newSupply = 1337;
        vm.prank(address(0xabcde));
        vm.expectRevert("Ownable: caller is not the owner");
        collection.updateSettings(newSupply, NO_UPDATE_U256, NO_UPDATE_U8, NO_UPDATE_ADDRESS);
    }

    function test_SetMintPrice() public {
        uint128 newPrice = 1337;
        vm.expectEmit(true, true, true, true);
        emit MintPriceUpdated(newPrice);
        collection.updateSettings(NO_UPDATE_U128, newPrice, NO_UPDATE_U8, NO_UPDATE_ADDRESS);

        assertEq(collection.mintPrice(), newPrice);
    }

    function test_UnauthorizedSetMintPrice() public {
        uint128 newPrice = 1337;
        vm.prank(address(0xabcde));
        vm.expectRevert("Ownable: caller is not the owner");
        collection.updateSettings(NO_UPDATE_U128, newPrice, NO_UPDATE_U8, NO_UPDATE_ADDRESS);
    }

    function test_SetProposerFee() public {
        uint8 newProposerFee = 2 * proposerFee;
        vm.expectEmit(true, true, true, true);
        emit ProposerFeeUpdated(newProposerFee);
        collection.updateSettings(NO_UPDATE_U128, NO_UPDATE_U256, newProposerFee, NO_UPDATE_ADDRESS);

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

        uint256 proposerRevenue = (mintPrice * newProposerFee) / 100;
        uint256 snapshotRevenue = (mintPrice * snapshotFee) / 100;
        // The space treasury received the mintPrice minus the proposer cut and the snapshot cut.
        assertEq(WETH.balanceOf(spaceTreasury), mintPrice - proposerRevenue - snapshotRevenue);

        // Snapshot received their revenue.
        assertEq(WETH.balanceOf(snapshotTreasury), snapshotRevenue);

        // The proposer received the proposer cut.
        assertEq(WETH.balanceOf(proposer), proposerRevenue);
    }

    function test_SetProposerFeeMax() public {
        uint8 newProposerFee = 100;

        vm.prank(snapshotOwner);
        collection.updateSnapshotSettings(0, NO_UPDATE_ADDRESS, NO_UPDATE_ADDRESS);

        vm.expectEmit(true, true, true, true);
        emit ProposerFeeUpdated(newProposerFee);
        collection.updateSettings(NO_UPDATE_U128, NO_UPDATE_U256, newProposerFee, NO_UPDATE_ADDRESS);

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
        collection.updateSettings(NO_UPDATE_U128, NO_UPDATE_U256, newProposerFee, NO_UPDATE_ADDRESS);

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
        vm.expectRevert(abi.encodeWithSelector(InvalidFee.selector));
        collection.updateSettings(NO_UPDATE_U128, NO_UPDATE_U256, newProposerFee, NO_UPDATE_ADDRESS);
    }

    function test_SetProposerFeeInvalidWithSnapshotFee() public {
        uint8 newProposerFee = 101 - snapshotFee;
        vm.expectRevert(abi.encodeWithSelector(InvalidFee.selector));
        collection.updateSettings(NO_UPDATE_U128, NO_UPDATE_U256, newProposerFee, NO_UPDATE_ADDRESS);
    }

    function test_SetProposerFeeUnauthorized() public {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0x123456789));
        collection.updateSettings(NO_UPDATE_U128, NO_UPDATE_U256, 50, NO_UPDATE_ADDRESS);
    }

    function test_SetProposerAndSnapshotFeesMin() public {
        uint8 newProposerFee = 0;
        uint8 newSnapshotFee = 0;
        vm.expectEmit(true, true, true, true);
        emit ProposerFeeUpdated(newProposerFee);
        collection.updateSettings(NO_UPDATE_U128, NO_UPDATE_U256, newProposerFee, NO_UPDATE_ADDRESS);

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

        // The space treasury received everything.
        assertEq(WETH.balanceOf(spaceTreasury), mintPrice);

        // Snapshot didn't receive anything.
        assertEq(WETH.balanceOf(snapshotTreasury), 0);

        // The proposer didn't receive anything.
        assertEq(WETH.balanceOf(proposer), 0);
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
        vm.expectRevert(abi.encodeWithSelector(Disabled.selector));
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
        vm.expectRevert(abi.encodeWithSelector(Disabled.selector));
        vm.prank(recipient);
        collection.mint(proposer, proposalId, salt, v, r, s);

        // Try to call `mintBatch` also
        address[] memory proposers = new address[](1);
        proposers[0] = proposer;
        uint256[] memory proposalIds = new uint256[](1);
        proposalIds[0] = proposalId;

        vm.expectRevert(abi.encodeWithSelector(Disabled.selector));
        vm.prank(recipient);
        collection.mintBatch(proposers, proposalIds, salt, v, r, s);

        vm.expectEmit(true, true, true, true);
        emit PowerSwitchUpdated(true);
        collection.setPowerSwitch(true);
        // This time, it shouldn't revert!
        vm.prank(recipient);
        collection.mint(proposer, proposalId, salt, v, r, s);
    }
}
