// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

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
import { IServiceFactory } from "../src/interfaces/IServiceFactory.sol";
import { IKeys } from "../src/interfaces/IKeys.sol";
import { IMAVault } from "../src/interfaces/IMAVault.sol";
import { ISAVault } from "../src/interfaces/ISAVault.sol";
import { ISafe } from "../src/interfaces/ISafe.sol";
import { IUpgradeHandler } from "../src/interfaces/IUpgradeHandler.sol";
import { IWETH } from "../src/interfaces/IWETH.sol";

import { AssetClass, Asset, VaultType, KeyConfig } from "../src/types/DataTypes.sol";

abstract contract Base is Script, Test {
    enum Deployment {
        DEFAULT,
        FORK
    }

    /// Type of deployment to use.
    Deployment deploymentType;

    /// Core contracts.
    SignerRegistry public signerRegistry;
    KYCRegistry public kycRegistry;
    KeyExchange public keyExchange;
    ServiceFactory public serviceFactory;
    ServiceFactoryProxy public serviceFactoryProxy;
    Keys public keys;
    MAVault public maVault;
    SAVault public saVault;
    Safe public safe;

    function coreSetup(address admin, address signer, address feeReceiver, address weth, uint256 factoryRole) public {
        /// Deploy registry contracts.
        signerRegistry = new SignerRegistry({ admin_: admin, signer_: signer });
        kycRegistry = new KYCRegistry({ admin_: admin, signerRegistry_: ISignerRegistry(signerRegistry) });

        /// Deploy ERC-1155 keys and exchange contract.
        keys = new Keys({ admin_: admin, uri_: "", kycRegistry_: IKYCRegistry(kycRegistry) });
        keyExchange = new KeyExchange({ admin_: admin, keys_: IKeys(keys), feeReceiver_: feeReceiver, weth_: weth });

        /// Call `setKeyExchange` on keys contract due to circular dependency.
        keys.setKeyExchange({ _keyExchange: address(keyExchange) });

        /// Deploy implementation contracts for each service.
        maVault = new MAVault();
        saVault = new SAVault();
        safe = new Safe();

        /// Deploy service factory implementation and proxy.
        serviceFactory = new ServiceFactory();
        serviceFactoryProxy = new ServiceFactoryProxy({
            implementation_: address(serviceFactory),
            payload_: abi.encodeWithSelector(
                ServiceFactory.initialize.selector,
                admin,
                address(maVault),
                address(saVault),
                address(safe),
                ISignerRegistry(signerRegistry),
                IKYCRegistry(kycRegistry),
                IKeys(keys)
            )
        });

        /// Grant `factoryRole` to service factory.
        keys.grantRoles({ user: address(serviceFactoryProxy), roles: factoryRole });
    }
}
