// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import { Test } from "forge-std/Test.sol";
import { SpaceCollection } from "../../src/SpaceCollection.sol";
import { ISpaceCollectionErrors } from "../../src/interfaces/spaceCollection/ISpaceCollectionErrors.sol";
import { ISpaceCollectionEvents } from "../../src/interfaces/spaceCollection/ISpaceCollectionEvents.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

abstract contract BaseCollection is Test, ISpaceCollectionErrors, ISpaceCollectionEvents {
    SpaceCollection public implem;
    SpaceCollection public collection;
    uint256 public constant SIGNER_PRIVATE_KEY = 1234;
    address public signerAddress;
    uint128 maxSupply = 10;
    // 0.1 WETH (1 + 17 * 0)
    uint256 mintPrice = 100000000000000000;
    uint8 proposerFee = 10;
    uint8 snapshotFee = 1;

    address proposer = address(0x4242424242);

    string NAME = "TestDAO";
    string VERSION = "0.1";

    uint256 salt = 0;
    address recipient = address(0x1234);
    uint256 proposalId = 42;

    address snapshotOwner = address(0x1111);
    address snapshotTreasury = address(0x2222);
    address spaceTreasury = address(0x3333);
    address spaceOwner = address(this);

    // Enough to mint 1000 items.
    uint256 INITIAL_WETH = mintPrice * 1000;

    // WETH address on Polygon.
    // MockERC20 WETH = MockERC20(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);

    // Goerli WETH
    MockERC20 WETH = MockERC20(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6);

    // bytes4(keccak256(bytes(
    //      "initialize(string,string,uint128,uint256,uint8,address,address,uint8,address,address,address)"
    //  )))
    bytes4 public constant SPACE_INITIALIZE_SELECTOR = 0x977b0efb;

    function setUp() public virtual {
        implem = new SpaceCollection();
        signerAddress = vm.addr(SIGNER_PRIVATE_KEY);
        vm.expectEmit(true, true, true, true);
        emit SpaceCollectionCreated(
            NAME,
            maxSupply,
            mintPrice,
            proposerFee,
            spaceTreasury,
            spaceOwner,
            snapshotFee,
            signerAddress,
            snapshotOwner,
            snapshotTreasury
        );
        collection = SpaceCollection(
            address(
                new ERC1967Proxy(
                    address(implem),
                    abi.encodeWithSelector(
                        SPACE_INITIALIZE_SELECTOR,
                        NAME,
                        VERSION,
                        maxSupply,
                        mintPrice,
                        proposerFee,
                        spaceTreasury,
                        spaceOwner,
                        snapshotFee,
                        signerAddress,
                        snapshotOwner,
                        snapshotTreasury
                    )
                )
            )
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
}
