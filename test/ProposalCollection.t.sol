// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/ProposalCollection.sol";
import { GasSnapshot } from "forge-gas-snapshot/GasSnapshot.sol";

contract ProposalCollectionTest is Test, GasSnapshot {
    // error InvalidSignature();
    // error SaltAlreadyUsed();

    ProposalCollection public collection;
    uint256 public constant SIGNER_PRIVATE_KEY = 1234;
    address public signerAddress;

    string NAME = "BUDDAO";
    string VERSION = "0.1";

    bytes32 private constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant MINT_TYPEHASH = keccak256("Mint(address to,uint256 proposalId,uint256 salt)");

    function setUp() public {
        signerAddress = vm.addr(SIGNER_PRIVATE_KEY);
        collection = new ProposalCollection(NAME, VERSION, signerAddress);
    }

    function _getDigest(address to, uint256 proposalId, uint256 salt) internal returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    keccak256(
                        abi.encode(
                            DOMAIN_TYPEHASH,
                            keccak256(bytes(NAME)),
                            keccak256(bytes(VERSION)),
                            block.chainid,
                            address(collection)
                        )
                    ),
                    keccak256(abi.encode(MINT_TYPEHASH, to, proposalId, salt))
                )
            );
    }

    function test_Mint() public {
        uint256 salt = 0;
        address to = address(0x1337);
        uint256 proposalId = 42;

        bytes32 digest = _getDigest(to, proposalId, salt);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        snapStart("FirstMint");
        collection.mint(to, proposalId, salt, v, r, s);
        snapEnd();

        assertEq(collection.balanceOf(to, proposalId), 1);
 

        salt += 1;
        digest = _getDigest(to, proposalId, salt);
        (v, r, s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        snapStart("SecondMint");
        collection.mint(to, proposalId, salt, v, r, s);
        snapEnd();

        assertEq(collection.balanceOf(to, proposalId), 2);
    }

    function test_MintSaltAlreadyUsed() public {
        uint256 salt = 0;
        address to = address(0x1337);
        uint256 proposalId = 42;

        bytes32 digest = _getDigest(to, proposalId, salt);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        collection.mint(to, proposalId, salt, v, r, s);

        // Ensure the NFT has been minted
        assertEq(collection.balanceOf(to, proposalId), 1);

        vm.expectRevert();
        collection.mint(to, proposalId, salt, v, r, s);
    }

    function test_MintInvalidSignature() public {
        uint256 salt = 0;
        address to = address(0x1337);
        uint256 proposalId = 42;

        bytes32 digest = _getDigest(to, proposalId, salt + 1);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PRIVATE_KEY, digest);
        vm.expectRevert();
        collection.mint(to, proposalId, salt, v, r, s);

        assertEq(collection.balanceOf(to, proposalId), 0);
    }
}
