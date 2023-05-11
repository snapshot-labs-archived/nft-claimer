// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "./utils/BaseCollection.t.sol";

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
}
