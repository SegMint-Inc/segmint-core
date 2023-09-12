// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Script.sol";
import "forge-std/Test.sol";

import { ERC1967Proxy } from "@openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

import { SignerRegistry } from "../src/registries/SignerRegistry.sol";
import { KYCRegistry } from "../src/registries/KYCRegistry.sol";
import { KeyExchange } from "../src/KeyExchange.sol";
import { VaultFactory } from "../src/factories/VaultFactory.sol";
import { Keys } from "../src/Keys.sol";
import { MAVault } from "../src/MAVault.sol";
import { SAVault } from "../src/SAVault.sol";

import { ISignerRegistry } from "../src/interfaces/ISignerRegistry.sol";
import { IKYCRegistry } from "../src/interfaces/IKYCRegistry.sol";
import { IKeyExchange } from "../src/interfaces/IKeyExchange.sol";
import { IVaultFactory } from "../src/interfaces/IVaultFactory.sol";
import { IKeys } from "../src/interfaces/IKeys.sol";
import { IMAVault } from "../src/interfaces/IMAVault.sol";
import { ISAVault } from "../src/interfaces/ISAVault.sol";
import { IUpgradeHandler } from "../src/interfaces/IUpgradeHandler.sol";
import { IOperatorFilter } from "../src/interfaces/IOperatorFilter.sol";
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
    VaultFactory public vaultFactory;
    ERC1967Proxy public vaultFactoryProxy;
    Keys public keys;
    MAVault public maVault;
    SAVault public saVault;

    function coreSetup(address admin, address signer, address feeReceiver, address weth, uint256 factoryRole) public {
        /// Deploy registry contracts.
        signerRegistry = new SignerRegistry({ admin_: admin, signer_: signer });
        kycRegistry = new KYCRegistry({ admin_: admin, signerRegistry_: ISignerRegistry(signerRegistry) });

        /// Deploy ERC-1155 keys and exchange contract.
        keys = new Keys({ admin_: admin, uri_: "", kycRegistry_: IKYCRegistry(kycRegistry) });
        keyExchange = new KeyExchange({
            admin_: admin,
            feeReceiver_: feeReceiver,
            weth_: weth,
            keys_: IKeys(keys),
            kycRegistry_: IKYCRegistry(kycRegistry)
        });

        /// Call `setKeyExchange` on keys contract due to circular dependency.
        keys.setKeyExchange({ newKeyExchange: address(keyExchange) });

        /// Deploy implementation contracts for each service.
        maVault = new MAVault();
        saVault = new SAVault();

        /// Deploy service factory implementation and proxy.
        vaultFactory = new VaultFactory();
        vaultFactoryProxy = new ERC1967Proxy({
            _logic: address(vaultFactory),
            _data: abi.encodeWithSelector(
                VaultFactory.initialize.selector,
                admin,
                address(maVault),
                address(saVault),
                ISignerRegistry(signerRegistry),
                IKYCRegistry(kycRegistry),
                IKeys(keys)
            )
        });

        /// Grant `factoryRole` to service factory.
        keys.grantRoles({ user: address(vaultFactoryProxy), roles: factoryRole });

        /// Interface the proxy contract with the implementation so that calls are delegated correctly.
        vaultFactory = VaultFactory(address(vaultFactoryProxy));
    }
}
