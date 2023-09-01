// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Base.sol";

import { ECDSA } from "solady/src/utils/ECDSA.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { IERC721 } from "@openzeppelin/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/token/ERC1155/IERC1155.sol";

import { UpgradeTest } from "./mocks/UpgradeTest.sol";
import { MockERC20 } from "./mocks/MockERC20.sol";
import { MockERC721 } from "./mocks/MockERC721.sol";
import { MockERC1155 } from "./mocks/MockERC1155.sol";

import { Assertions } from "./utils/Assertions.sol";
import { Events } from "./utils/Events.sol";
import { Users } from "./utils/Users.sol";

abstract contract BaseTest is Base, Assertions, Events {
    using ECDSA for bytes32;

    /// Constants.
    uint256 public constant ADMIN_ROLE = 0x4a4566510e9351b52a3e4f6550fc68d8577350bec07d7a69da4906b0efe533bc;
    uint256 public constant FACTORY_ROLE = 0xee961466e472802bc53e28ea01e7875c1285a5d1f1992f7b1aafc450304db8bc;
    address public constant FEE_RECEIVER = address(0xFEE5);
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    bytes4 public constant UNAUTHORIZED_SELECTOR = 0x82b42900;

    /// Define test users.
    Users public users;

    /// Mock contracts.
    UpgradeTest public upgradeTest;
    MockERC20 public mockERC20;
    MockERC721 public mockERC721;
    MockERC1155 public mockERC1155;

    function setUp() public virtual {
        /// Deploy mocks.
        upgradeTest = new UpgradeTest();
        mockERC20 = new MockERC20();
        mockERC721 = new MockERC721();
        mockERC1155 = new MockERC1155();

        /// Initialize users.
        createUsers();

        /// Deploy core contracts.
        coreSetup({
            admin: users.admin,
            signer: users.signer.account,
            feeReceiver: FEE_RECEIVER,
            weth: WETH,
            factoryRole: FACTORY_ROLE
        });
    }

    /// Initializes accounts that will be used for testing.
    function createUsers() private {
        users.admin = makeAddr("Admin");

        (users.signer.account, users.signer.privateKey) = makeAddrAndKey("Signer");

        (users.alice.account, users.alice.privateKey) = makeAddrAndKey("Alice");
        deal({ token: address(mockERC20), to: users.alice.account, give: 1_000_000 ether });
        mockERC721.mint({ receiver: users.alice.account, amount: 1 });
        mockERC1155.mint({ receiver: users.alice.account, id: 0, amount: 1 });

        (users.bob.account, users.bob.privateKey) = makeAddrAndKey("Bob");
        deal({ token: address(mockERC20), to: users.bob.account, give: 1_000_000 ether });
        mockERC721.mint({ receiver: users.bob.account, amount: 1 });
        mockERC1155.mint({ receiver: users.bob.account, id: 0, amount: 1 });

        (users.eve.account, users.eve.privateKey) = makeAddrAndKey("Eve");
        deal({ token: address(mockERC20), to: users.eve.account, give: 1_000_000 ether });
        mockERC721.mint({ receiver: users.eve.account, amount: 1 });
        mockERC1155.mint({ receiver: users.eve.account, id: 0, amount: 1 });
    }

    /// KYC'd the respective users, in this case Alice and Bob.
    function kycUsers() internal {
        startHoax(users.admin);
        kycRegistry.modifyAccessType({ account: users.alice.account, newAccessType: IKYCRegistry.AccessType.RESTRICTED });
        kycRegistry.modifyAccessType({ account: users.bob.account, newAccessType: IKYCRegistry.AccessType.RESTRICTED });
        vm.stopPrank();
    }

    /// Returns an ERC20 asset owned by Alice.
    function getERC20Asset() internal view returns (Asset memory) {
        return Asset({
            class: AssetClass.ERC20,
            token: address(mockERC20),
            identifier: 0,
            amount: 100 ether
        });
    }

    /// Returns an ERC721 asset owned by Alice.
    function getERC721Asset() internal view returns (Asset memory) {
        return Asset({
            class: AssetClass.ERC721,
            token: address(mockERC721),
            identifier: 0,
            amount: 1 
        });
    }

    /// Returns an ERC1155 asset owned by Alice.
    function getERC1155Asset() internal view returns (Asset memory) {
        return Asset({
            class: AssetClass.ERC1155,
            token: address(mockERC1155),
            identifier: 0,
            amount: 1 
        });
    }

    /// Returns all assets owned by Alice.
    function getAssets() internal view returns (Asset[] memory) {
        Asset[] memory assets = new Asset[](3);
        assets[0] = getERC20Asset();
        assets[1] = getERC721Asset();
        assets[2] = getERC1155Asset();
        return assets;
    }

    /// Used for {KYCRegistry.initAccessType}.
    function getAccessSignature(address account, uint256 deadline, IKYCRegistry.AccessType accessType)
        internal
        view
        returns (bytes memory)
    {
        bytes32 digest = keccak256(abi.encodePacked(account, deadline, accessType)).toEthSignedMessageHash();
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