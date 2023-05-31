// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import { SpaceCollection } from "../../src/SpaceCollection.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { MockERC20 } from "test/mocks/MockERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

abstract contract BaseCollection is Test {
    error InvalidSignature();
    error SaltAlreadyUsed();
    error MaxSupplyReached();

    event MaxSupplyUpdated(uint128 newSupply);
    event MintPriceUpdated(uint256 mintPrice);
    event SpaceCollectionCreated(
        uint256 spaceId,
        uint256 mintPrice,
        uint128 maxSupply,
        uint8 proposerCut,
        address trustedBackend,
        address spaceTreasury
    );

    SpaceCollection public implem;
    SpaceCollection public collection;
    uint256 public constant SIGNER_PRIVATE_KEY = 1234;
    address public signerAddress;
    uint128 maxSupply = 10;
    // 0.1 WETH (1 + 17 * 0)
    uint256 mintPrice = 100000000000000000;
    uint8 proposerFee = 10;
    uint256 spaceId = 1337;

    address proposer = address(0x4242424242);

    string NAME = "NFT-CLAIMER";
    string VERSION = "0.1";

    uint256 salt = 0;
    address recipient = address(0x1234);
    uint256 proposalId = 42;
    address spaceTreasury = address(0xabcd);

    // Enough to mint 1000 items.
    uint256 INITIAL_WETH = mintPrice * 1000;

    // WETH address on Polygon.
    // MockERC20 WETH = MockERC20(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);

    // Goerli WETH
    MockERC20 WETH = MockERC20(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6);

    function setUp() public virtual {
        implem = new SpaceCollection();
        signerAddress = vm.addr(SIGNER_PRIVATE_KEY);
        vm.expectEmit(true, true, true, true);
        emit SpaceCollectionCreated(spaceId, mintPrice, maxSupply, proposerFee, signerAddress, spaceTreasury);
        collection = SpaceCollection(
            address(
                new ERC1967Proxy(
                    address(implem),
                    abi.encodeWithSelector(
                        SpaceCollection.initialize.selector,
                        NAME,
                        VERSION,
                        spaceId,
                        maxSupply,
                        mintPrice,
                        proposerFee,
                        signerAddress,
                        spaceTreasury
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
