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

    /// @notice TODO
    error MaxSupplyReached();

    /// @notice Thrown if a user has already used a specific salt.
    error SaltAlreadyUsed();

    /// @notice TODO
    error InvalidFee(uint8 proposerFee);

    /// @notice TODO
    error CallerIsNotSnapshot();

    /// @notice TODO
    error CallerIsNotTreasury();

    event MaxSupplyUpdated(uint128 maxSupply);
    event MintPriceUpdated(uint256 mintPrice);
    event SpaceCollectionCreated(
        string spaceId,
        uint256 mintPrice,
        uint128 maxSupply,
        uint8 proposerFee,
        uint8 snapshotFee,
        address trustedBackend,
        address snapshotOwner,
        address snapshotTreasury,
        address spaceTreasury
    );
    event ProposerFeeUpdated(uint8 proposerFee);
    event SnapshotFeeUpdated(uint8 snapshotFee);
    event SnapshotOwnerUpdated(address snapshotOwner);
    event SnapshotTreasuryUpdated(address snapshotTreasury);

    bytes32 private constant MINT_TYPEHASH =
        keccak256("Mint(address proposer,address recipient,uint256 proposalId,uint256 salt)");
    bytes32 private constant MINT_BATCH_TYPEHASH =
        keccak256("MintBatch(address[] proposers,address recipient,uint256[] proposalIds,uint256 salt)");

    // Polygon
    // IERC20 private constant WETH = IERC20(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);

    // Goerli SCOTT
    IERC20 private constant WETH = IERC20(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6);

    address public trustedBackend;

    uint128 public maxSupply;

    uint256 public mintPrice;

    address public spaceTreasury;

    address public snapshotTreasury;

    address public snapshotOwner;

    uint256 snapshotBalance;
    uint256 spaceBalance;

    // A single slot that holds the proposerFee (first 8 bits) and the snapshotFee (8-16th bits).
    uint256 fees;

    // A uint256 that contains both the currentSupply (first 128 bits) and the maxSupply (last 128 bits.
    mapping(uint256 proposalId => uint256 supply) public supplies;

    mapping(uint256 proposalId => uint256 price) public mintPrices;

    mapping(address recipient => mapping(uint256 salt => bool used)) private usedSalts;

    function initialize(
        string memory name,
        string memory version,
        string memory _spaceId,
        uint128 _maxSupply,
        uint256 _mintPrice,
        uint8 _proposerFee,
        uint8 _snapshotFee,
        address _trustedBackend,
        address _snapshotOwner,
        address _snapshotTreasury,
        address _spaceTreasury
    ) public initializer {
        __Ownable_init();
        __ERC1155_init("");
        __EIP712_init(name, version);
        maxSupply = _maxSupply;
        mintPrice = _mintPrice;
        if (_proposerFee > 100) revert InvalidFee(_proposerFee);
        if (_snapshotFee > 100) revert InvalidFee(_snapshotFee);
        fees = _proposerFee + (uint256(_snapshotFee) << 8);
        trustedBackend = _trustedBackend;
        snapshotOwner = _snapshotOwner;
        snapshotTreasury = _snapshotTreasury;
        spaceTreasury = _spaceTreasury;

        emit SpaceCollectionCreated(
            _spaceId,
            _mintPrice,
            _maxSupply,
            _proposerFee,
            _snapshotFee,
            _trustedBackend,
            _snapshotOwner,
            _snapshotTreasury,
            _spaceTreasury
        );
    }

    function setMaxSupply(uint128 _maxSupply) public onlyOwner {
        maxSupply = _maxSupply;
        emit MaxSupplyUpdated(_maxSupply);
    }

    function setMintPrice(uint256 _mintPrice) public onlyOwner {
        mintPrice = _mintPrice;
        emit MintPriceUpdated(_mintPrice);
    }

    function setProposerFee(uint8 _proposerFee) public onlyOwner {
        if (_proposerFee > 100) revert InvalidFee(_proposerFee);
        // 0xFF00 because we take the 8 highest bits of `fees` (snapshotFee).
        fees = (0xFF00 & fees) + _proposerFee;
        emit ProposerFeeUpdated(_proposerFee);
    }

    function setSnapshotFee(uint8 _snapshotFee) public {
        if (msg.sender != snapshotOwner) revert CallerIsNotSnapshot();
        if (_snapshotFee > 100) revert InvalidFee(_snapshotFee);

        fees = uint8(fees) + (uint256(_snapshotFee) << 8);
        emit SnapshotFeeUpdated(_snapshotFee);
    }

    function setSnapshotTreasury(address _snapshotTreasury) public {
        if (msg.sender != snapshotOwner) revert CallerIsNotSnapshot();

        snapshotTreasury = _snapshotTreasury;
        emit SnapshotTreasuryUpdated(_snapshotTreasury);
    }

    function setSnapshotOwner(address _snapshotOwner) public {
        if (msg.sender != snapshotOwner) revert CallerIsNotSnapshot();

        snapshotOwner = _snapshotOwner;
        emit SnapshotOwnerUpdated(_snapshotOwner);
    }

    function snapshotClaim() public {
        if (msg.sender != snapshotTreasury) revert CallerIsNotTreasury();

        WETH.transfer(snapshotTreasury, snapshotBalance);
        snapshotBalance = 0;
    }

    function spaceClaim() public {
        if (msg.sender != spaceTreasury) revert CallerIsNotTreasury();

        WETH.transfer(spaceTreasury, spaceBalance);
        spaceBalance = 0;
    }

    function mint(address proposer, uint256 proposalId, uint256 salt, uint8 v, bytes32 r, bytes32 s) public {
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
            _hashTypedDataV4(keccak256(abi.encode(MINT_TYPEHASH, proposer, msg.sender, proposalId, salt))),
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
        supplies[proposalId] = (uint256(maxSupply_) << 128) + currentSupply;

        uint256 spaceRevenue = price;

        // snapshotFees are the first 8 bits of `fees`.
        uint8 proposerFee = uint8(fees);
        uint256 proposerRevenue = (spaceRevenue * proposerFee) / 100;
        spaceRevenue -= proposerRevenue;

        // snapshotFees are the 8-16 bits of `fees`.
        uint8 snapshotFee = uint8(fees >> 8);
        // snapshotRevenue is computed AFTER the proposer cut.
        uint256 snapshotRevenue = (spaceRevenue * snapshotFee) / 100;
        spaceRevenue -= snapshotRevenue;

        // Proceed to payment.
        WETH.transferFrom(msg.sender, proposer, proposerRevenue);
        WETH.transferFrom(msg.sender, address(this), spaceRevenue + snapshotRevenue);

        // Update the snapshot and space balances.
        snapshotBalance += snapshotRevenue;
        spaceBalance += spaceRevenue;

        // Proceed to minting.
        _mint(msg.sender, proposalId, 1, "");
    }

    function mintBatch(
        address[] calldata proposers,
        uint256[] calldata proposalIds,
        uint256 salt,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        // todo: check that proposalIds should be unique

        // Check sig.
        address recoveredAddress = ECDSA.recover(
            _hashTypedDataV4(keccak256(abi.encode(MINT_BATCH_TYPEHASH, proposers, msg.sender, proposalIds, salt))),
            v,
            r,
            s
        );

        if (recoveredAddress != trustedBackend) revert InvalidSignature();
        if (usedSalts[msg.sender][salt]) revert SaltAlreadyUsed();

        // Mark salt as used to prevent replay attacks
        usedSalts[msg.sender][salt] = true;

        uint256 totalSnapshotRevenue;
        uint256 totalSpaceRevenue;

        // Array of `1`s. Needs to be dynamically filled.
        uint256[] memory amounts = new uint256[](proposers.length);

        for (uint256 i = 0; i < proposers.length; i++) {
            // Add a `1` to the array.
            amounts[i] = 1;

            // Get the current proposer and proposalId.
            address proposer = proposers[i];
            uint256 proposalId = proposalIds[i];

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

            // Increase current supply
            currentSupply += 1;

            // Store back the supply
            supplies[proposalId] = (uint256(maxSupply_) << 128) + currentSupply;

            // Transfer to space treasury
            uint256 spaceRevenue = price;

            // snapshotFees are the first 8 bits of `fees`.
            uint8 proposerFee = uint8(fees);
            uint256 proposerRevenue = (spaceRevenue * proposerFee) / 100;
            spaceRevenue -= proposerRevenue;

            // snapshotFees are the 8-16 bits of `fees`.
            uint8 snapshotFee = uint8(fees >> 8);
            // snapshotRevenue is computed AFTER the proposer cut.
            uint256 snapshotRevenue = (spaceRevenue * snapshotFee) / 100;
            spaceRevenue -= snapshotRevenue;

            // TODO: we might be able to optimize this by doing batch transfers if `proposers` repeat.
            WETH.transferFrom(msg.sender, proposer, proposerRevenue);

            // Do not transfer to the space and to snapshot, but accumulate the revenues.
            totalSnapshotRevenue += snapshotRevenue;
            totalSpaceRevenue += spaceRevenue;
        }

        // Transfer the total revenues.
        WETH.transferFrom(msg.sender, snapshotTreasury, totalSnapshotRevenue);
        WETH.transferFrom(msg.sender, spaceTreasury, totalSpaceRevenue);

        // Proceed to payment.
        _mintBatch(msg.sender, proposalIds, amounts, "");
    }

    /// @dev Only the Space owner can authorize an upgrade to this contract.
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
