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

// uint256(keccak256(abi.encodePacked("No update")))
uint256 constant NO_UPDATE_U256 = 0xf2cda9b13ed04e585461605c0d6e804933ca828111bd94d4e6a96c75e8b048ba;

// uint128(bytes16(keccak256(abi.encodePacked("No update"))))
uint128 constant NO_UPDATE_U128 = 0xf2cda9b13ed04e585461605c0d6e8049;

// address(bytes20(keccak256(abi.encodePacked("No update"))))
address constant NO_UPDATE_ADDRESS = address(0xF2CDA9b13eD04E585461605c0d6e804933Ca8281);

// uint8(bytes1(keccak256(abi.encodePacked("No update"))))
uint8 constant NO_UPDATE_U8 = 0xf2;

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
    /// @notice Internal structure used to pack fees in a single storage slot.
    struct Fees {
        uint8 proposerFee;
        uint8 snapshotFee;
    }

    /// @notice Internal structure used to pack supplies in a memory storage slot.
    struct SupplyData {
        uint128 currentSupply;
        uint128 maxSupply;
    }

    /// @notice The `Mint` typehash as defined in EIP712.
    bytes32 private constant MINT_TYPEHASH =
        keccak256("Mint(address proposer,address recipient,uint256 proposalId,uint256 salt)");

    /// @notice The `MintBatch` typehash as defined in EIP712.
    bytes32 private constant MINT_BATCH_TYPEHASH =
        keccak256("MintBatch(address[] proposers,address recipient,uint256[] proposalIds,uint256 salt)");

    // Polygon
    // IERC20 private constant WETH = IERC20(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);

    // Goerli SCOTT
    IERC20 private constant WETH = IERC20(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6);

    /// @notice The verifiedSigner signs needs to provide a signature to the user
    ///         for the functions `mint` and `mintBatch` to work.
    address public verifiedSigner;

    /// @notice The maxSupply is set per subcollection. When a new subcollection is first minted, it uses `maxSupply` to determine
    ///         the maximum number of mintable NFTs.
    uint128 public maxSupply;

    /// @notice The maxSupply is set per subcollection. When a new subcollection is first minted, it uses `mintPrice` to determine
    ///         the mint price of items in this subcollection.
    uint256 public mintPrice;

    /// @notice The space-owned address to which the minting proceeds will be sent to.
    address public spaceTreasury;

    /// @notice The snapshot-owned address to which the minting fees will be sent to.
    address public snapshotTreasury;

    /// @notice The snapshot owner address that has the right to modify itself, the `verifiedSigner`,
    ///         as well as  the `snapshotTreasury` address.
    address public snapshotOwner;

    /// @notice A boolean to indicate whether minting is enabled or not.
    bool public enabled;

    /// @notice Storage variable for fees.
    Fees public fees;

    /// @notice Mapping that holds the supply information for each subcollection.
    mapping(uint256 proposalId => SupplyData supply) public supplies;

    /// @notice Mapping that holds the mint prices for each subcollection.
    mapping(uint256 proposalId => uint256 price) public mintPrices;

    /// @notice Mapping used to store a `salt` for each recipient (used to avoid signature replays).
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
        address _verifiedSigner,
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
        verifiedSigner = _verifiedSigner;
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
            _verifiedSigner,
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
    function updateSettings(
        uint128 _maxSupply,
        uint256 _mintPrice,
        uint8 _proposerFee,
        address _spaceTreasury
    ) external onlyOwner {
        if (_maxSupply != NO_UPDATE_U128) {
            _setMaxSupply(_maxSupply);
        }

        if (_mintPrice != NO_UPDATE_U256) {
            _setMintPrice(_mintPrice);
        }

        if (_proposerFee != NO_UPDATE_U8) {
            _setProposerFee(_proposerFee);
        }

        if (_spaceTreasury != NO_UPDATE_ADDRESS) {
            _setSpaceTreasury(_spaceTreasury);
        }
    }

    function _setMaxSupply(uint128 _maxSupply) internal {
        if (_maxSupply == 0) revert SupplyCannotBeZero();

        maxSupply = _maxSupply;
        emit MaxSupplyUpdated(_maxSupply);
    }

    function _setMintPrice(uint256 _mintPrice) internal {
        mintPrice = _mintPrice;
        emit MintPriceUpdated(_mintPrice);
    }

    function _setProposerFee(uint8 _proposerFee) internal {
        if (_proposerFee > 100) revert InvalidFee();
        if ((_proposerFee + fees.snapshotFee) > 100) revert InvalidFee();

        fees.proposerFee = _proposerFee;
        emit ProposerFeeUpdated(_proposerFee);
    }

    function _setSpaceTreasury(address _spaceTreasury) internal {
        spaceTreasury = _spaceTreasury;
        emit SpaceTreasuryUpdated(_spaceTreasury);
    }

    /// @notice inheritdoc ISpaceCollection
    function setPowerSwitch(bool enable) external onlyOwner {
        enabled = enable;
        emit PowerSwitchUpdated(enable);
    }

    /// @notice inheritdoc ISpaceCollection
    function updateSnapshotSettings(uint8 _snapshotFee, address _snapshotTreasury, address _verifiedSigner) external {
        if (msg.sender != snapshotOwner) revert CallerIsNotSnapshot();

        if (_snapshotFee != NO_UPDATE_U8) {
            _setSnapshotFee(_snapshotFee);
        }

        if (_snapshotTreasury != NO_UPDATE_ADDRESS) {
            _setSnapshotTreasury(_snapshotTreasury);
        }

        if (_verifiedSigner != NO_UPDATE_ADDRESS) {
            _setVerifiedSigner(_verifiedSigner);
        }
    }

    /// @notice inheritdoc ISpaceCollection
    function _setSnapshotFee(uint8 _snapshotFee) internal {
        if (_snapshotFee > 100) revert InvalidFee();
        if ((fees.proposerFee + _snapshotFee) > 100) {
            // Update `proposerFee`, with `_snapshotFee` taking priority.
            fees.proposerFee = 100 - _snapshotFee;
            emit ProposerFeeUpdated(100 - _snapshotFee);
        }

        fees.snapshotFee = _snapshotFee;
        emit SnapshotFeeUpdated(_snapshotFee);
    }

    /// @notice inheritdoc ISpaceCollection
    function _setSnapshotTreasury(address _snapshotTreasury) internal {
        snapshotTreasury = _snapshotTreasury;
        emit SnapshotTreasuryUpdated(_snapshotTreasury);
    }

    /// @notice inheritdoc ISpaceCollection
    function _setVerifiedSigner(address _verifiedSigner) internal {
        if (_verifiedSigner == address(0)) revert AddressCannotBeZero();

        verifiedSigner = _verifiedSigner;
        emit VerifiedSignerUpdated(_verifiedSigner);
    }

    /// @notice inheritdoc ISpaceCollection
    function setSnapshotOwner(address _snapshotOwner) external {
        if (msg.sender != snapshotOwner) revert CallerIsNotSnapshot();

        snapshotOwner = _snapshotOwner;
        emit SnapshotOwnerUpdated(_snapshotOwner);
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
        // We use inequality with zero rather than equality with true for gas optimization reasons.
        if (usedSalts[msg.sender][salt] != FALSE) revert SaltAlreadyUsed();

        // Check sig.
        address recoveredAddress = ECDSA.recover(
            _hashTypedDataV4(keccak256(abi.encode(MINT_TYPEHASH, proposer, msg.sender, proposalId, salt))),
            v,
            r,
            s
        );

        if (recoveredAddress != verifiedSigner) revert InvalidSignature();

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

        if (recoveredAddress != verifiedSigner) revert InvalidSignature();
        // We use inequality with zero rather than equality with true for gas optimization reasons.
        if (usedSalts[msg.sender][salt] != FALSE) revert SaltAlreadyUsed();

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
