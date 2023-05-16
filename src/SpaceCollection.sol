// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { EIP712Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title Space Collection
/// @notice The Space NFT contract
///         A proxy of this contract should be deployed with the Proxy Factory.
contract SpaceCollection is Initializable, UUPSUpgradeable, OwnableUpgradeable, ERC1155Upgradeable, EIP712Upgradeable {
    /// @notice Thrown if a signature is invalid.
    error InvalidSignature();

    /// @notice
    error MaxSupplyReached();

    /// @notice Thrown if a user has already used a specific salt.
    error SaltAlreadyUsed();

    event MaxSupplyUpdated(uint128 maxSupply);
    event MintPriceUpdated(uint256 mintPrice);
    event SpaceCollectionCreated(uint256 mintPrice, uint128 maxSupply, address trustedBackend, address spaceTreasury);

    bytes32 private constant MINT_TYPEHASH = keccak256("Mint(address recipient,uint256 proposalId,uint256 salt)");

    // Polygon
    // IERC20 private constant WETH = IERC20(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);

    // Goerli SCOTT
    IERC20 private constant WETH = IERC20(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6);

    address public trustedBackend;

    uint128 public maxSupply;

    uint256 public mintPrice;

    address public spaceTreasury;

    // A uint256 that contains both the currentSupply (first 128 bits) and the maxSupply (last 128 bits.
    mapping(uint256 proposalId => uint256 supply) public supplies;

    mapping(uint256 proposalId => uint256 price) public mintPrices;

    mapping(address recipient => mapping(uint256 salt => bool used)) private usedSalts;

    function initialize(
        string memory name,
        string memory version,
        uint128 _maxSupply,
        uint256 _mintPrice,
        address _trustedBackend,
        address _spaceTreasury
    ) public initializer {
        __Ownable_init();
        __ERC1155_init("");
        __EIP712_init(name, version);
        trustedBackend = _trustedBackend;
        mintPrice = _mintPrice;
        maxSupply = _maxSupply;
        spaceTreasury = _spaceTreasury;

        emit SpaceCollectionCreated(_mintPrice, _maxSupply, _trustedBackend, _spaceTreasury);
    }

    function setMaxSupply(uint128 _maxSupply) public onlyOwner {
        maxSupply = _maxSupply;
        emit MaxSupplyUpdated(_maxSupply);
    }

    function setMintPrice(uint256 _mintPrice) public onlyOwner {
        mintPrice = _mintPrice;
        emit MintPriceUpdated(_mintPrice);
    }

    // TODO: setProposerCut
    // TODO: setSnapshotController

    function mint(uint256 proposalId, uint256 salt, uint8 v, bytes32 r, bytes32 s) public {
        uint256 data = supplies[proposalId];

        uint128 currentSupply = uint128(data);
        uint128 maxSupply_;
        uint256 price;

        if (currentSupply == 0) {
            // If this is the first time minting, set the max supply.
            maxSupply_ = uint128(maxSupply);

            // Also set the mint price.
            price = mintPrice;
            mintPrices[proposalId] = price;
        } else {
            // Else retrieve the stored max supply.
            maxSupply_ = uint128(data >> 128);

            // And retrieve the mint price.
            price = mintPrices[proposalId];
        }

        if (currentSupply >= maxSupply) revert MaxSupplyReached();
        if (usedSalts[msg.sender][salt]) revert SaltAlreadyUsed();

        // Check sig.
        address recoveredAddress = ECDSA.recover(
            _hashTypedDataV4(keccak256(abi.encode(MINT_TYPEHASH, msg.sender, proposalId, salt))),
            v,
            r,
            s
        );

        if (recoveredAddress != trustedBackend) revert InvalidSignature();

        // Mark salt as used to prevent replay attacks
        usedSalts[msg.sender][salt] = true;
        // Increase current supply
        currentSupply += 1;
        // Store back the supply
        // TODO: optimize?
        supplies[proposalId] = (uint256(maxSupply_) << 128) + currentSupply;

        // Transfer to space treasury
        WETH.transferFrom(msg.sender, spaceTreasury, price);
        // Proceed to payment.
        _mint(msg.sender, proposalId, 1, "");
    }

    /// @dev Only the Space owner can authorize an upgrade to this contract.
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
