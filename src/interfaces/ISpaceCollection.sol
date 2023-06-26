// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { ISpaceCollectionErrors } from "./spaceCollection/ISpaceCollectionErrors.sol";
import { ISpaceCollectionEvents } from "./spaceCollection/ISpaceCollectionEvents.sol";

interface ISpaceCollection is ISpaceCollectionErrors, ISpaceCollectionEvents {
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
    ) external;

    function setMaxSupply(uint128 _maxSupply) external;

    function setMintPrice(uint256 _mintPrice) external;

    function setProposerFee(uint8 _proposerFee) external;

    function setSnapshotFee(uint8 _snapshotFee) external;

    function setSnapshotOwner(address _snapshotOwner) external;

    function setVerifiedSigner(address _verifiedSigner) external;

    function setPowerSwitch(bool enable) external;

    function mint(address proposer, uint256 proposalId, uint256 salt, uint8 v, bytes32 r, bytes32 s) external;

    function mintBatch(
        address[] calldata proposers,
        uint256[] calldata proposalIds,
        uint256 salt,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}
