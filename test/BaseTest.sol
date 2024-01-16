// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/console2.sol";
import "./Base.sol";

import { ECDSA } from "@solady/src/utils/ECDSA.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/token/ERC1155/IERC1155.sol";
import { IDelegateRegistry } from "@delegate-registry/src/IDelegateRegistry.sol";

import { MockERC20 } from "./mocks/MockERC20.sol";
import { MockERC721 } from "./mocks/MockERC721.sol";
import { MockERC1155 } from "./mocks/MockERC1155.sol";
import { MockUpgrade } from "./mocks/MockUpgrade.sol";
import { MockWETH } from "./mocks/MockWETH.sol";

import { Assertions } from "./utils/Assertions.sol";
import { Events } from "./utils/Events.sol";
import { Users } from "./utils/Users.sol";

abstract contract BaseTest is Base, Assertions, Events {
    using stdJson for string;
    using ECDSA for bytes32;

    /// Constants.
    address public constant FEE_RECEIVER = address(0xFEE5);

    bytes4 public constant UNAUTHORIZED_SELECTOR = 0x82b42900;

    /// Default amount of mock ERC20 tokens to give to a user.
    uint256 public constant ERC20_BALANCE = 1_000_000 ether;
    /// Default amount of mock ERC721 tokens to give to a user.
    uint256 public constant ERC721_AMOUNT = 1;
    /// Default ERC1155 ID.
    uint256 public constant ERC1155_ID = 0;
    /// Default amount of mock ERC1155 tokens to give to a user.
    uint256 public constant ERC1155_AMOUNT = 1;

    /// Alice's ERC721 token ID.
    uint256 public constant ALICE_721_ID = 0;

    /// Define test users.
    Users public users;

    /// Mock contracts.
    MockERC20 public mockERC20;
    MockERC721 public mockERC721;
    MockERC1155 public mockERC1155;
    address public mockUpgrade;
    MockWETH public mockWETH;
    IDelegateRegistry public delegateRegistry;

    function setUp() public virtual {
        /// Deploy mocks.
        mockERC20 = new MockERC20();
        mockERC721 = new MockERC721();
        mockERC1155 = new MockERC1155();
        mockUpgrade = address(new MockUpgrade());
        mockWETH = new MockWETH();

        /// Etch code into delegate V2 registry.
        string memory root = vm.projectRoot();
        string memory basePath = string.concat(root, "/test/utils/");
        string memory path = string.concat(basePath, "delegateRegistry.json");
        string memory jsonFile = vm.readFile(path);

        delegateRegistry = abi.decode(vm.parseJson(jsonFile, ".registryAddress"), (IDelegateRegistry));
        bytes memory delegateCode = abi.decode(vm.parseJson(jsonFile, ".code"), (bytes));
        vm.etch({ target: address(delegateRegistry), newRuntimeBytecode: delegateCode });

        /// Initialize users.
        createUsers();

        /// Deploy core contracts.
        coreSetup({
            admin: users.admin,
            signer: users.signer.account,
            feeReceiver: FEE_RECEIVER,
            weth: address(mockWETH)
        });
    }

    /// Initializes accounts that will be used for testing.
    function createUsers() private {
        users.admin = makeAddr("Admin");

        (users.signer.account, users.signer.privateKey) = makeAddrAndKey("Signer");

        (users.alice.account, users.alice.privateKey) = makeAddrAndKey("Alice");
        deal({ to: users.alice.account, give: 1_000 ether });
        deal({ token: address(mockERC20), to: users.alice.account, give: ERC20_BALANCE });
        mockERC721.mint({ receiver: users.alice.account, amount: ERC721_AMOUNT });
        mockERC1155.mint({ receiver: users.alice.account, id: ERC1155_ID, amount: ERC1155_AMOUNT });

        (users.bob.account, users.bob.privateKey) = makeAddrAndKey("Bob");
        deal({ to: users.bob.account, give: 1_000 ether });
        deal({ token: address(mockERC20), to: users.bob.account, give: ERC20_BALANCE });
        mockERC721.mint({ receiver: users.bob.account, amount: ERC721_AMOUNT });
        mockERC1155.mint({ receiver: users.bob.account, id: ERC1155_ID, amount: ERC1155_AMOUNT });

        (users.eve.account, users.eve.privateKey) = makeAddrAndKey("Eve");
        deal({ to: users.eve.account, give: 1_000 ether });
        deal({ token: address(mockERC20), to: users.eve.account, give: ERC20_BALANCE });
        mockERC721.mint({ receiver: users.eve.account, amount: ERC721_AMOUNT });
        mockERC1155.mint({ receiver: users.eve.account, id: ERC1155_ID, amount: ERC1155_AMOUNT });
    }

    /// KYC'd the respective users, in this case Alice and Bob.
    function kycUsers() internal {
        startHoax(users.admin);
        accessRegistry.modifyAccessType({
            account: users.alice.account,
            newAccessType: IAccessRegistry.AccessType.RESTRICTED
        });
        accessRegistry.modifyAccessType({
            account: users.bob.account,
            newAccessType: IAccessRegistry.AccessType.RESTRICTED
        });
        vm.stopPrank();
    }

    /// Returns an ERC20 asset owned by Alice.
    function getERC20Asset() internal view returns (Asset memory) {
        return Asset({ class: AssetClass.ERC20, token: address(mockERC20), identifier: 0, amount: 100 ether });
    }

    /// Returns an ERC721 asset owned by Alice.
    function getERC721Asset() internal view returns (Asset memory) {
        return Asset({ class: AssetClass.ERC721, token: address(mockERC721), identifier: 0, amount: 1 });
    }

    /// Returns an ERC1155 asset owned by Alice.
    function getERC1155Asset() internal view returns (Asset memory) {
        return Asset({ class: AssetClass.ERC1155, token: address(mockERC1155), identifier: 0, amount: 1 });
    }

    /// Returns all assets owned by Alice.
    function getAssets() internal view returns (Asset[] memory) {
        Asset[] memory assets = new Asset[](3);
        assets[0] = getERC20Asset();
        assets[1] = getERC721Asset();
        assets[2] = getERC1155Asset();
        return assets;
    }

    /// Returns an array of random addresses.
    function getHolders(uint256 amount) internal pure returns (address[] memory) {
        address[] memory addresses = new address[](amount);
        for (uint256 i = 0; i < amount; i++) {
            addresses[i] = address(uint160(uint256(keccak256(abi.encodePacked(i)))));
        }
        return addresses;
    }

    function getAmounts(uint256 length) internal pure returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](length);
        for (uint256 i = 0; i < length; i++) {
            amounts[i] = 1;
        }
        return amounts;
    }

    /// Used for {KYCRegistry.initAccessType}.
    function getAccessSignature(address account, uint256 deadline, IAccessRegistry.AccessType accessType)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = keccak256(abi.encodePacked(account, deadline, accessType)).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign({ privateKey: users.signer.privateKey, digest: digest });
        return abi.encodePacked(r, s, v);
    }

    /// Used for {KYCRegistry.initAccessType}.
    function getAccessSignature(IAccessRegistry.AccessParams memory accessParams)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = accessRegistry.hashAccessParams(accessParams);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign({ privateKey: users.signer.privateKey, digest: digest });
        return abi.encodePacked(r, s, v);
    }

    /// Used for {ServiceFactory} vault creation functions.
    function getVaultCreationSignature(address account, uint256 nonce, VaultType vaultType)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = keccak256(abi.encodePacked(account, block.chainid, nonce, vaultType)).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign({ privateKey: users.signer.privateKey, digest: digest });
        return abi.encodePacked(r, s, v);
    }
}
