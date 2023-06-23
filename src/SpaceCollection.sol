// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { EIP712Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ISpaceCollection } from "./interfaces/ISpaceCollection.sol";

/// @dev `uint256` boolean values to use in mappings for gas efficiency.
uint256 constant TRUE = 1;
uint256 constant FALSE = 0;

/// @title Space Collection
/// @notice The Space NFT contract
///         A proxy of this contract should be deployed with the Proxy Factory.
contract SpaceCollection is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ERC1155Upgradeable,
    EIP712Upgradeable,
    ISpaceCollection
{
    // todo
    struct Fees {
        uint8 proposerFee;
        uint8 snapshotFee;
    }

    // todo
    struct SupplyData {
        uint128 currentSupply;
        uint128 maxSupply;
    }

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

    bool enabled;

    Fees public fees;

    mapping(uint256 proposalId => SupplyData supply) public supplies;

    mapping(uint256 proposalId => uint256 price) public mintPrices;

    mapping(address recipient => mapping(uint256 salt => uint256 used)) private usedSalts;

    /// @inheritdoc ISpaceCollection
    function initialize(
        string memory name,
        string memory version,
        uint128 _maxSupply,
        uint256 _mintPrice,
        uint8 _proposerFee,
        address _spaceTreasury,
        address _spaceOwner,
        uint8 _snapshotFee,
        address _trustedBackend,
        address _snapshotOwner,
        address _snapshotTreasury
    ) external initializer {
        __Ownable_init();
        transferOwnership(_spaceOwner);

        __ERC1155_init("");
        __EIP712_init(name, version);
        maxSupply = _maxSupply;
        mintPrice = _mintPrice;
        if (_proposerFee > 100) revert InvalidFee();
        if (_snapshotFee > 100) revert InvalidFee();
        if ((_proposerFee + _snapshotFee) > 100) revert InvalidFee();

        fees = Fees(_proposerFee, _snapshotFee);
        trustedBackend = _trustedBackend;
        snapshotOwner = _snapshotOwner;
        snapshotTreasury = _snapshotTreasury;
        spaceTreasury = _spaceTreasury;
        enabled = true;

        emit SpaceCollectionCreated(
            name,
            _maxSupply,
            _mintPrice,
            _proposerFee,
            _spaceTreasury,
            _spaceOwner,
            _snapshotFee,
            _trustedBackend,
            _snapshotOwner,
            _snapshotTreasury
        );
    }

    /// @notice Throws if a duplicate is found in `arr`.
    /// @param  arr the array to check.
    /// @dev    O(n^2) implementation.
    function _assertNoDuplicates(uint256[] calldata arr) internal pure {
        // TODO: gas-snapshot and optimize it with linear approach (by bounding number of proposalIDs)
        for (uint256 i = 0; i < arr.length - 1; i++) {
            for (uint256 j = i + 1; j < arr.length; j++) {
                if (arr[i] == arr[j]) revert DuplicatesFound();
            }
        }
    }

    /// @notice inheritdoc ISpaceCollection
    function setMaxSupply(uint128 _maxSupply) external onlyOwner {
        if (_maxSupply == 0) revert SupplyCannotBeZero();

        maxSupply = _maxSupply;
        emit MaxSupplyUpdated(_maxSupply);
    }

    /// @notice inheritdoc ISpaceCollection
    function setMintPrice(uint256 _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
        emit MintPriceUpdated(_mintPrice);
    }

    /// @notice inheritdoc ISpaceCollection
    function setProposerFee(uint8 _proposerFee) external onlyOwner {
        if (_proposerFee > 100) revert InvalidFee();
        if ((_proposerFee + fees.snapshotFee) > 100) revert InvalidFee();

        fees.proposerFee = _proposerFee;
        emit ProposerFeeUpdated(_proposerFee);
    }

    /// @notice inheritdoc ISpaceCollection
    function setSnapshotFee(uint8 _snapshotFee) external {
        if (msg.sender != snapshotOwner) revert CallerIsNotSnapshot();
        if (_snapshotFee > 100) revert InvalidFee();
        if ((fees.proposerFee + _snapshotFee) > 100) revert InvalidFee();

        fees.snapshotFee = _snapshotFee;
        emit SnapshotFeeUpdated(_snapshotFee);
    }

    /// @notice inheritdoc ISpaceCollection
    function setSnapshotTreasury(address _snapshotTreasury) external {
        if (msg.sender != snapshotOwner) revert CallerIsNotSnapshot();

        snapshotTreasury = _snapshotTreasury;
        emit SnapshotTreasuryUpdated(_snapshotTreasury);
    }

    /// @notice inheritdoc ISpaceCollection
    function setSnapshotOwner(address _snapshotOwner) external {
        if (msg.sender != snapshotOwner) revert CallerIsNotSnapshot();

        snapshotOwner = _snapshotOwner;
        emit SnapshotOwnerUpdated(_snapshotOwner);
    }

    /// @notice inheritdoc ISpaceCollection
    function setTrustedBackend(address _trustedBackend) external {
        if (msg.sender != snapshotOwner) revert CallerIsNotSnapshot();
        if (_trustedBackend == address(0)) revert AddressCannotBeZero();

        trustedBackend = _trustedBackend;
        emit TrustedBackendUpdated(_trustedBackend);
    }

    /// @notice inheritdoc ISpaceCollection
    function setPowerSwitch(bool enable) external onlyOwner {
        enabled = enable;
        emit PowerSwitchUpdated(enable);
    }

    /// @notice Throws if `enabled == false`.
    modifier isEnabled() {
        if (enabled == false) revert Disabled();
        _;
    }

    /// @notice inheritdoc ISpaceCollection
    function mint(
        address proposer,
        uint256 proposalId,
        uint256 salt,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external isEnabled {
        SupplyData memory supplyData = supplies[proposalId];

        uint256 price;

        if (supplyData.currentSupply == 0) {
            // If this is the first time minting, set the max supply.
            supplyData.maxSupply = maxSupply;

            // Also set the mint price.
            price = mintPrice;
            mintPrices[proposalId] = price;
        } else {
            // Else retrieve the mint price.
            price = mintPrices[proposalId];
        }

        if (supplyData.currentSupply >= supplyData.maxSupply) revert MaxSupplyReached();
        if (usedSalts[msg.sender][salt] == TRUE) revert SaltAlreadyUsed();

        // Check sig.
        address recoveredAddress = ECDSA.recover(
            _hashTypedDataV4(keccak256(abi.encode(MINT_TYPEHASH, proposer, msg.sender, proposalId, salt))),
            v,
            r,
            s
        );

        if (recoveredAddress != trustedBackend) revert InvalidSignature();

        // Mark salt as used to prevent replay attacks
        usedSalts[msg.sender][salt] = TRUE;
        // Increase current supply
        supplyData.currentSupply += 1;

        // Write the new supplyData
        supplies[proposalId] = supplyData;

        uint256 proposerRevenue = (price * fees.proposerFee) / 100;
        uint256 snapshotRevenue = (price * fees.snapshotFee) / 100;

        // Proceed to payment.
        WETH.transferFrom(msg.sender, proposer, proposerRevenue);
        WETH.transferFrom(msg.sender, snapshotTreasury, snapshotRevenue);
        WETH.transferFrom(msg.sender, spaceTreasury, price - proposerRevenue - snapshotRevenue);

        // Proceed to minting.
        _mint(msg.sender, proposalId, 1, "");
    }

    /// @notice inheritdoc ISpaceCollection
    function mintBatch(
        address[] calldata proposers,
        uint256[] calldata proposalIds,
        uint256 salt,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external isEnabled {
        _assertNoDuplicates(proposalIds);

        // Check sig.
        address recoveredAddress = ECDSA.recover(
            _hashTypedDataV4(keccak256(abi.encode(MINT_BATCH_TYPEHASH, proposers, msg.sender, proposalIds, salt))),
            v,
            r,
            s
        );

        if (recoveredAddress != trustedBackend) revert InvalidSignature();
        if (usedSalts[msg.sender][salt] == TRUE) revert SaltAlreadyUsed();

        // Mark salt as used to prevent replay attacks
        usedSalts[msg.sender][salt] = TRUE;

        uint256 totalSnapshotRevenue;
        uint256 totalSpaceRevenue;

        // Array of `1`s or `0`s. Needs to be dynamically filled.
        uint256[] memory amounts = new uint256[](proposers.length);

        for (uint256 i = 0; i < proposers.length; i++) {
            SupplyData memory supplyData = supplies[proposalIds[i]];
            uint256 price;
            if (supplyData.currentSupply == 0) {
                // If this is the first time minting, set the max supply.
                supplyData.maxSupply = maxSupply;

                // Also set the mint price.
                price = mintPrice;
                mintPrices[proposalIds[i]] = price;
            } else {
                price = mintPrices[proposalIds[i]];
            }

            if (supplyData.currentSupply >= supplyData.maxSupply) {
                // Add a `0` to the array.
                amounts[i] = 0;
                continue;
            }

            // Increase current supply
            supplyData.currentSupply += 1;

            // Add a `1` to the array.
            amounts[i] = 1;

            // Write the new supplyData.
            supplies[proposalIds[i]] = supplyData;

            // Transfer to space treasury
            uint256 spaceRevenue = price;

            uint256 proposerRevenue = (spaceRevenue * fees.proposerFee) / 100;
            uint256 snapshotRevenue = (spaceRevenue * fees.snapshotFee) / 100;

            spaceRevenue -= snapshotRevenue + proposerRevenue;

            // TODO: we might be able to optimize this by doing batch transfers if `proposers` repeat.
            WETH.transferFrom(msg.sender, proposers[i], proposerRevenue);

            // Do not transfer to the space and to snapshot, but accumulate the revenues.
            totalSnapshotRevenue += snapshotRevenue;
            totalSpaceRevenue += spaceRevenue;
        }

        // Transfer the total revenues.
        WETH.transferFrom(msg.sender, snapshotTreasury, totalSnapshotRevenue);
        WETH.transferFrom(msg.sender, spaceTreasury, totalSpaceRevenue);

        // Proceed to minting.
        _mintBatch(msg.sender, proposalIds, amounts, "");
    }

    /// @dev Only the Space owner can authorize an upgrade to this contract.
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
