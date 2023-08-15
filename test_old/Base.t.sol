// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Test } from "forge-std/Test.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";

import { ISegMintSignerModule } from "../src/interfaces/ISegMintSignerModule.sol";
import { ISegMintKYCRegistry } from "../src/interfaces/ISegMintKYCRegistry.sol";
import { ISegMintKeys } from "../src/interfaces/ISegMintKeys.sol";
import { ISegMintSafe } from "../src/interfaces/ISegMintSafe.sol";
import { ISegMintVault } from "../src/interfaces/ISegMintVault.sol";
import { ISegMintVaultSingle } from "../src/interfaces/ISegMintVaultSingle.sol";
import { ISegMintFactory } from "../src/interfaces/ISegMintFactory.sol";
import { ISegMintFactoryProxy } from "../src/interfaces/ISegMintFactoryProxy.sol";
import { ISegMintKeyExchange } from "../src/interfaces/ISegMintKeyExchange.sol";

import { SegMintSignerModule } from "../src/SegMintSignerModule.sol";
import { SegMintKYCRegistry } from "../src/SegMintKYCRegistry.sol";
import { SegMintKeys } from "../src/SegMintKeys.sol";
import { SegMintSafe } from "../src/SegMintSafe.sol";
import { SegMintVault } from "../src/SegMintVault.sol";
import { SegMintVaultSingle } from "../src/SegMintVaultSingle.sol";
import { SegMintFactory } from "../src/SegMintFactory.sol";
import { SegMintFactoryProxy } from "../src/SegMintFactoryProxy.sol";
import { SegMintKeyExchange } from "../src/SegMintKeyExchange.sol";

import { SignerManagerMock } from "./mocks/SignerManagerMock.sol";

import { Constants } from "./utils/Constants.sol";
import { Events } from "./utils/Events.sol";

import { Users } from "./utils/Types.sol";
import { Errors } from "../src/libraries/Errors.sol";
import { AssetType, KYCRegistry, Vault, Factory, Keys } from "../src/types/DataTypes.sol";

import { SomeERC20 } from "./token/SomeERC20.sol";
import { SomeERC721 } from "./token/SomeERC721.sol";
import { SomeERC1155 } from "./token/SomeERC1155.sol";

contract Base is Constants, Events, Test {
    using ECDSA for bytes32;

    SegMintSignerModule public signerModule;
    SegMintKYCRegistry public kycRegistry;
    SegMintKeys public keys;
    SegMintSafe public safeImplementation;
    SegMintVault public vaultImplementation;
    SegMintVaultSingle public vaultSingleImplementation;
    SegMintFactory public factory;
    SegMintFactoryProxy public factoryProxy;
    SegMintKeyExchange public keyExchange;

    SignerManagerMock public signerManager;

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
        keyExchange = new SegMintKeyExchange({protocolFee_: 150, signer_: SIGNER, keys_: ISegMintKeys(address(0))});
        keys =
        new SegMintKeys({ admin_: users.admin, uri_: "", kycRegistry_: kycRegistry, keyExchange_: address(keyExchange) });

        vaultImplementation = new SegMintVault();
        vaultSingleImplementation = new SegMintVaultSingle();
        safeImplementation = new SegMintSafe();

        factory = new SegMintFactory();

        /// forgefmt: disable-next-item
        bytes memory initPayload = abi.encodeWithSelector(
            ISegMintFactory.initialize.selector,
            users.admin,
            vaultImplementation,
            vaultSingleImplementation,
            safeImplementation,
            signerModule,
            kycRegistry,
            keys
        );

        factoryProxy = new SegMintFactoryProxy({
            admin_: users.admin,
            implementation_: address(factory),
            payload_: initPayload
        });

        signerManager = new SignerManagerMock();
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
     * Returns the signature required for {SegMintFactory.createVault}.
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

    /**
     * Returns the signature required for {SegMintFactory.createVaultSingle}.
     */
    function getCreateVaultSingleSignature(address account, KYCRegistry.AccessType accessType)
        internal
        pure
        returns (bytes memory)
    {
        bytes32 digest =
            keccak256(abi.encodePacked(account, accessType, "CREATE_VAULT_SINGLE")).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, digest);
        return abi.encodePacked(r, s, v);
    }
}
