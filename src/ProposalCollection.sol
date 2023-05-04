// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { EIP712 } from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract ProposalCollection is ERC1155, EIP712 {
    /// @notice Thrown if a signature is invalid.
    error InvalidSignature();

    /// @notice Thrown if a user has already used a specific salt.
    error SaltAlreadyUsed();

    bytes32 private constant MINT_TYPEHASH = keccak256("Mint(address to,uint256 proposalId,uint256 salt)");

    address public trustedBackend;

    mapping(address to => mapping(uint256 salt => bool used)) private usedSalts;

    // solhint-disable-next-line no-empty-blocks
    // TODO set supply
    constructor(string memory name, string memory version, address _trustedBackend) ERC1155("") EIP712(name, version) {
        trustedBackend = _trustedBackend;
    }

    function rev() public {
        revert SaltAlreadyUsed();
    }

    function mint(address to, uint256 proposalId, uint256 salt, uint8 v, bytes32 r, bytes32 s) public {
        // todo check current supply doesn't exceed max supply
        if (usedSalts[to][salt]) revert SaltAlreadyUsed();

        // Check sig.
        address recoveredAddress = ECDSA.recover(
            _hashTypedDataV4(keccak256(abi.encode(MINT_TYPEHASH, to, proposalId, salt))),
            v,
            r,
            s
        );

        if (recoveredAddress != trustedBackend) revert InvalidSignature();

        // Mark salt as used to prevent replay attacks
        usedSalts[to][salt] = true;

        _mint(to, proposalId, 1, "");
    }
}
