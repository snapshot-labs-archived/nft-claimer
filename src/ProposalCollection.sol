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

    /// @notice
    error MaxSupplyReached();

    bytes32 private constant MINT_TYPEHASH = keccak256("Mint(address recipient,uint256 proposalId,uint256 salt)");

    address public trustedBackend;

    uint128 public maxSupplyPerProposal;

    mapping(uint256 proposalId => uint256 supply) public supplies;

    mapping(address recipient => mapping(uint256 salt => bool used)) private usedSalts;

    // solhint-disable-next-line no-empty-blocks
    constructor(
        string memory name,
        string memory version,
        uint128 _maxSupplyPerProposal,
        address _trustedBackend
    ) ERC1155("") EIP712(name, version) {
        trustedBackend = _trustedBackend;
        maxSupplyPerProposal = _maxSupplyPerProposal;
    }

    function mint(address recipient, uint256 proposalId, uint256 salt, uint8 v, bytes32 r, bytes32 s) public {
        uint256 data = supplies[proposalId];

        uint128 currentSupply = uint128(data);
        uint128 maxSupply;

        if (currentSupply == 0) {
            // If this is the first time minting, set the max supply.
            maxSupply = uint128(maxSupplyPerProposal);
        } else {
            // Else retrieve the stored max supply.
            maxSupply = uint128(data >> 128);
        }

        if (currentSupply >= maxSupply) revert MaxSupplyReached();
        if (usedSalts[recipient][salt]) revert SaltAlreadyUsed();

        // Check sig.
        address recoveredAddress = ECDSA.recover(
            _hashTypedDataV4(keccak256(abi.encode(MINT_TYPEHASH, recipient, proposalId, salt))),
            v,
            r,
            s
        );

        if (recoveredAddress != trustedBackend) revert InvalidSignature();

        // Mark salt as used to prevent replay attacks
        usedSalts[recipient][salt] = true;
        // Increase current supply
        currentSupply += 1;
        // Store back the supply
        // TODO: optimize?
        supplies[proposalId] = (uint256(maxSupply) << 128) + currentSupply;

        _mint(recipient, proposalId, 1, "");
    }
}
