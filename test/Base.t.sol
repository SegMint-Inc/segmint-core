// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Test } from "forge-std/Test.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";

import { ISegMintSignerModule } from "../src/interfaces/ISegMintSignerModule.sol";
import { ISegMintKYCRegistry } from "../src/interfaces/ISegMintKYCRegistry.sol";
import { ISegMintKeys } from "../src/interfaces/ISegMintKeys.sol";
import { ISegMintVault } from "../src/interfaces/ISegMintVault.sol";
import { ISegMintVaultManager } from "../src/interfaces/ISegMintVaultManager.sol";
import { ISegMintVaultManagerProxy } from "../src/interfaces/ISegMintVaultManagerProxy.sol";

import { SegMintSignerModule } from "../src/SegMintSignerModule.sol";
import { SegMintKYCRegistry } from "../src/SegMintKYCRegistry.sol";
import { SegMintKeys } from "../src/SegMintKeys.sol";
import { SegMintVault } from "../src/SegMintVault.sol";
import { SegMintVaultManager } from "../src/SegMintVaultManager.sol";
import { SegMintVaultManagerProxy } from "../src/SegMintVaultManagerProxy.sol";

import { Constants } from "./utils/Constants.sol";
import { Events } from "./utils/Events.sol";

import { Users } from "./utils/Types.sol";
import { Errors } from "../src/libraries/Errors.sol";
import { Class, KYCRegistry, Vault, VaultManager, Keys } from "../src/types/DataTypes.sol";

import { SomeERC20 } from "./token/SomeERC20.sol";
import { SomeERC721 } from "./token/SomeERC721.sol";
import { SomeERC1155 } from "./token/SomeERC1155.sol";

contract Base is Constants, Events, Test {
    using ECDSA for bytes32;

    SegMintSignerModule public signerModule;
    SegMintKYCRegistry public kycRegistry;
    SegMintKeys public keys;
    SegMintVault public vaultImplementation;
    SegMintVaultManager public vaultManager;
    SegMintVaultManagerProxy public vaultManagerProxy;

    SomeERC20 public erc20;
    SomeERC721 public erc721;
    SomeERC1155 public erc1155;

    Users public users;

    function setUp() public virtual {
        erc20 = new SomeERC20();
        erc721 = new SomeERC721();
        erc1155 = new SomeERC1155();

        users = Users({
            admin: createUser("admin"),
            alice: createUser("alice"),
            bob: createUser("bob"),
            eve: createUser("eve")
        });

        signerModule = new SegMintSignerModule({admin_: users.admin, signer_: SIGNER});
        kycRegistry = new SegMintKYCRegistry({admin_: users.admin, signerModule_: signerModule});
        keys = new SegMintKeys({admin_: users.admin, uri_: "", kycRegistry_: kycRegistry});

        vaultImplementation = new SegMintVault();

        vaultManager = new SegMintVaultManager();

        bytes memory initPayload = abi.encodeWithSelector(
            ISegMintVaultManager.initialize.selector, users.admin, vaultImplementation, signerModule, kycRegistry
        );

        vaultManagerProxy = new SegMintVaultManagerProxy({
            admin_: users.admin,
            implementation_: address(vaultManager),
            payload_: initPayload
        });
    }

    /* Helper Functions */

    /**
     * Generates a user, labels its address, and funds it with test assets.
     */
    function createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        vm.deal({ account: user, newBalance: 100 ether });
        deal({ token: address(erc20), to: user, give: 1_000_000e18 });
        erc721.mint(user, 1);
        erc1155.mint(user, ERC1155_TOKEN_ID, 1);
        return user;
    }

    /**
     * Registers the respective users to the associated KYC status.
     */
    function kycUsers() internal {
        startHoax(users.admin, users.admin);
        kycRegistry.modifyAccessType(users.alice, KYCRegistry.AccessType.RESTRICTED);
        kycRegistry.modifyAccessType(users.bob, KYCRegistry.AccessType.UNRESTRICTED);
        vm.stopPrank();
    }

    /**
     * Returns the signature required for {SegMintKYCRegistry.initAccessType}.
     */
    function getAccessSignature(address account, KYCRegistry.AccessType accessType)
        internal
        pure
        returns (bytes memory)
    {
        bytes32 digest = keccak256(abi.encodePacked(account, accessType, "INIT_ACCESS_TYPE")).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, digest);
        return abi.encodePacked(r, s, v);
    }

    /**
     * Returns the signature required for {SegMintVaultManager.createVault}.
     */
    function getCreateVaultSignature(address account, KYCRegistry.AccessType accessType)
        internal
        pure
        returns (bytes memory)
    {
        bytes32 digest = keccak256(abi.encodePacked(account, accessType, "CREATE_VAULT")).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, digest);
        return abi.encodePacked(r, s, v);
    }
}
