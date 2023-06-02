// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "./utils/BaseCollection.t.sol";
import "./utils/Digests.sol";

contract OwnerTest is BaseCollection {
    event ProposerFeeUpdated(uint8 proposerCut);
    error InvalidFee(uint8 proposerFee);

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

        // mint them and check
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

        uint256 proposerCut = (mintPrice * newProposerFee) / 100;
        // The space treasury received the mintPrice minus the proposer cut
        assertEq(WETH.balanceOf(spaceTreasury), mintPrice - proposerCut);

        // The proposer received the proposer cut.
        assertEq(WETH.balanceOf(proposer), proposerCut);
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

        // The space treasury received the mintPrice minus the proposer cut
        assertEq(WETH.balanceOf(spaceTreasury), 0);

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

        // The space treasury received the mintPrice minus the proposer cut
        assertEq(WETH.balanceOf(spaceTreasury), mintPrice);

        // The proposer received the proposer cut.
        assertEq(WETH.balanceOf(proposer), 0);
    }

    function test_SetProposerFeeInvalid() public {
        uint8 newProposerFee = 101;
        vm.expectRevert(abi.encodeWithSelector(InvalidFee.selector, newProposerFee));
        collection.setProposerFee(newProposerFee);
    }

    function test_SetProposerFeeUnauthorized() public {
        uint8 newProposerFee = 50;
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(address(0x123456789));
        collection.setProposerFee(50);
    }
}
