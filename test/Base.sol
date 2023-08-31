// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import { ECDSA } from "solady/src/utils/ECDSA.sol";

import { SignerRegistry } from "../src/registries/SignerRegistry.sol";
import { KYCRegistry } from "../src/registries/KYCRegistry.sol";
import { KeyExchange } from "../src/KeyExchange.sol";
import { ServiceFactoryProxy } from "../src/factories/ServiceFactoryProxy.sol";
import { ServiceFactory } from "../src/factories/ServiceFactory.sol";
import { Keys } from "../src/Keys.sol";
import { MAVault } from "../src/MAVault.sol";
import { SAVault } from "../src/SAVault.sol";
import { Safe } from "../src/Safe.sol";

import { ISignerRegistry } from "../src/interfaces/ISignerRegistry.sol";
import { IKYCRegistry } from "../src/interfaces/IKYCRegistry.sol";
import { IKeyExchange } from "../src/interfaces/IKeyExchange.sol";
import { IServiceFactoryProxy } from "../src/interfaces/IServiceFactoryProxy.sol";
import { IServiceFactory } from "../src/interfaces/IServiceFactory.sol";
import { IKeys } from "../src/interfaces/IKeys.sol";
import { IMAVault } from "../src/interfaces/IMAVault.sol";
import { ISAVault } from "../src/interfaces/ISAVault.sol";
import { ISafe } from "../src/interfaces/ISafe.sol";
import { IWETH } from "../src/interfaces/IWETH.sol";

import { AssetClass, Asset } from "../src/types/DataTypes.sol";

import { DemoERC20 } from "./tokens/DemoERC20.sol";
import { DemoERC721 } from "./tokens/DemoERC721.sol";
import { DemoERC1155 } from "./tokens/DemoERC1155.sol";

import { Events } from "./utils/Events.sol";
import { Users } from "./utils/Users.sol";

abstract contract Base is Script, Test, Events {
    using ECDSA for bytes32;

    /// Variables.
    uint256 public constant ADMIN_ROLE = 0x4a4566510e9351b52a3e4f6550fc68d8577350bec07d7a69da4906b0efe533bc;
    uint256 public constant FACTORY_ROLE = 0xee961466e472802bc53e28ea01e7875c1285a5d1f1992f7b1aafc450304db8bc;
    address public constant FEE_RECEIVER = address(0xFEE5);
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    bytes4 public constant UNAUTHORIZED_SELECTOR = 0x82b42900;

    uint256 public alicePrivateKey;
    uint256 public bobPrivateKey;

    uint256 public signerPrivateKey;
    address public signer;

    /// Users.
    Users public users;

    /// Test tokens for asset locking.
    DemoERC20 public demoERC20;
    DemoERC721 public demoERC721;
    DemoERC1155 public demoERC1155;

    /// Core contracts.
    SignerRegistry public signerRegistry;
    KYCRegistry public kycRegistry;
    KeyExchange public keyExchange;
    ServiceFactoryProxy public serviceFactoryProxy;
    ServiceFactory public serviceFactoryImplementation;
    ServiceFactory public serviceFactoryProxied;
    Keys public keys;
    MAVault public maVault;
    SAVault public saVault;
    Safe public safe;

    function setUp() public virtual {
        /// Load signer from env.
        signerPrivateKey = vm.envUint("SIGNER_PRIVATE_KEY");
        signer = vm.addr(signerPrivateKey);

        /// Deploy test tokens.
        demoERC20 = new DemoERC20();
        demoERC721 = new DemoERC721();
        demoERC1155 = new DemoERC1155();

        /// Create users for testing.
        users = Users({
            admin: createUser("Admin"),
            alice: createUserAndSetKeyA("Alice"),
            bob: createUserAndSetKeyB("Bob"),
            eve: createUser("Eve")
        });

        /// Deploy base registry contracts.
        signerRegistry = new SignerRegistry({ admin_: users.admin, signer_: signer });
        kycRegistry = new KYCRegistry({ admin_: users.admin, signerRegistry_: ISignerRegistry(signerRegistry) });
        keys = new Keys({ admin_: users.admin, uri_: "", kycRegistry_: IKYCRegistry(kycRegistry) });
        keyExchange = new KeyExchange({ admin_: users.admin, keys_: IKeys(keys), feeReceiver_: FEE_RECEIVER, weth_: WETH });

        /// Set exchange address in keys contract.
        hoax(users.admin, users.admin);
        keys.setKeyExchange({ _keyExchange: address(keyExchange) });

        /// Deploy implementation addresses for service factory.
        saVault = new SAVault();
        maVault = new MAVault();
        safe = new Safe();

        /// Deploy service factory implementation and proxy.
        serviceFactoryImplementation = new ServiceFactory();
        serviceFactoryProxy = new ServiceFactoryProxy({
            implementation_: address(serviceFactoryImplementation),
            payload_: abi.encodeWithSelector(
                ServiceFactory.initialize.selector,
                users.admin,
                address(maVault),
                address(saVault),
                address(safe),
                ISignerRegistry(signerRegistry),
                IKYCRegistry(kycRegistry),
                IKeys(keys)
            )
        });

        /// Proxy the service factory through the service factory proxy.
        serviceFactoryProxied = ServiceFactory(address(serviceFactoryProxy));

        /// Grant service factory the correct role for vault registration.
        keys.grantRoles({ user: address(serviceFactoryProxied), roles: FACTORY_ROLE });
    }

    /// Helper Functions
    function createUserAndSetKeyA(string memory name) internal returns (address payable) {
        (address user, uint256 privateKey) = makeAddrAndKey(name);
        alicePrivateKey = privateKey;

        vm.deal({ account: user, newBalance: 100 ether });
        deal({ token: address(demoERC20), to: user, give: 1_000_000 ether });

        startHoax(user, user);
        demoERC721.mint({ receiver: user, amount: 5 });
        demoERC1155.mint({ receiver: user, amount: 5, id: 1 });
        vm.stopPrank();

        return payable(user);
    }

    function createUserAndSetKeyB(string memory name) internal returns (address payable) {
        (address user, uint256 privateKey) = makeAddrAndKey(name);
        bobPrivateKey = privateKey;

        vm.deal({ account: user, newBalance: 100 ether });
        deal({ token: address(demoERC20), to: user, give: 1_000_000 ether });

        startHoax(user, user);
        demoERC721.mint({ receiver: user, amount: 5 });
        demoERC1155.mint({ receiver: user, amount: 5, id: 1 });
        vm.stopPrank();

        return payable(user);
    }

    function createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));

        vm.deal({ account: user, newBalance: 100 ether });
        deal({ token: address(demoERC20), to: user, give: 1_000_000 ether });

        startHoax(user, user);
        demoERC721.mint({ receiver: user, amount: 5 });
        demoERC1155.mint({ receiver: user, amount: 5, id: 1 });
        vm.stopPrank();

        return user;
    }

    /// Used for {KYCRegistry.initAccessType}.
    function getAccessSignature(address account, uint256 deadline, IKYCRegistry.AccessType accessType)
        internal
        view
        returns (bytes memory)
    {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign({
            privateKey: signerPrivateKey,
            digest: keccak256(abi.encodePacked(account, deadline, accessType)).toEthSignedMessageHash()
        });
        return abi.encodePacked(r, s, v);
    }

    /// Used for {ServiceFactory} vault creation functions.
    function getVaultCreateSignature(
        address account,
        IKYCRegistry.AccessType accessType,
        uint256 nonce,
        string memory discriminator
    ) internal view returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign({
            privateKey: signerPrivateKey,
            digest: keccak256(abi.encodePacked(account, accessType, block.chainid, nonce, discriminator))
                .toEthSignedMessageHash()
        });
        return abi.encodePacked(r, s, v);
    }
}
