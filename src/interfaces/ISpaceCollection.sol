// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import { ISpaceCollectionErrors } from "./spaceCollection/ISpaceCollectionErrors.sol";
import { ISpaceCollectionEvents } from "./spaceCollection/ISpaceCollectionEvents.sol";

interface ISpaceCollection is ISpaceCollectionErrors, ISpaceCollectionEvents {}
