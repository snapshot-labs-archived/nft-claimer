// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/ProposalCollection.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";
import { GasSnapshot } from "forge-gas-snapshot/GasSnapshot.sol";

contract ProposalCollectionTest is Test, GasSnapshot {
    error InvalidSignature();
    error SaltAlreadyUsed();
    error MaxSupplyReached();

    ProposalCollection public collection;
    uint256 public constant SIGNER_PRIVATE_KEY = 1234;
    address public signerAddress;
    uint128 maxSupplyPerProposal = 10;
    uint256 mintPrice = 1;

    string NAME = "BUDDAO";
    string VERSION = "0.1";

    bytes32 private constant DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant MINT_TYPEHASH = keccak256("Mint(address recipient,uint256 proposalId,uint256 salt)");

    uint256 salt = 0;
    address recipient = address(0x1234);
    uint256 proposalId = 42;
    address spaceTreasury = address(0xabcd);

    uint256 INITIAL_WETH = 1000;

    MockERC20 WETH = MockERC20(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);

    function setUp() public {
        signerAddress = vm.addr(SIGNER_PRIVATE_KEY);
        collection = new ProposalCollection(
            NAME,
            VERSION,
            maxSupplyPerProposal,
            mintPrice,
            signerAddress,
            spaceTreasury
        );

        // Deploy mock contract
        deployFakeWeth();

        // Mint tokens
        WETH.mint(recipient, INITIAL_WETH);

        vm.startPrank(recipient);
        // Approve the contract to spend the WETH.
        WETH.approve(address(collection), INITIAL_WETH);
    }

    /// Deploys a mock ERC20 contract at the WETH address on Polygon.
    function deployFakeWeth() public {
        // Deploy
        bytes memory args = abi.encode("Mocked WETH", "MWETH");
        bytes memory bytecode = abi.encodePacked(vm.getCode("MockERC20.sol:MockERC20"), args);
        address deployed;
        assembly {
            deployed := create(0, add(bytecode, 0x20), mload(bytecode))
        }

        // Set the bytecode of the WETH address
        vm.etch(address(WETH), deployed.code);
    }

    function _getDigest(address _recipient, uint256 _proposalId, uint256 _salt) internal view returns (bytes32) {
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
                    keccak256(abi.encode(MINT_TYPEHASH, _recipient, _proposalId, _salt))
                )
            );
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

        for (uint256 i = 0; i < maxSupplyPerProposal; i++) {
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
