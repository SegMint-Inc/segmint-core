// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ISegMintKYCRegistry } from "../../src/interfaces/ISegMintKYCRegistry.sol";
import { ISegMintVault } from "../../src/interfaces/ISegMintVault.sol";
import { ISegMintSignerModule } from "../../src/interfaces/ISegMintSignerModule.sol";
import { KYCRegistry } from "../../src/types/DataTypes.sol";

abstract contract Events {
    event SignerUpdated(address indexed admin, address oldSigner, address newSigner);

    event AccessTypeSet(address indexed account, KYCRegistry.AccessType accessType);

    event AccessTypeModified(
        address indexed admin,
        address indexed account,
        KYCRegistry.AccessType oldAccessType,
        KYCRegistry.AccessType newAccessType
    );

    event VaultCreated(address indexed user, ISegMintVault indexed vault);

    event UpgradeProposed(address indexed admin, address implementation, uint40 deadline);

    event UpgradeCancelled(address indexed admin, address implementation);

    event SignerModuleUpdated(
        address indexed admin, ISegMintSignerModule oldSignerModule, ISegMintSignerModule newSignerModule
    );

    event KeysCreated(address indexed vault, uint256 keyId, uint256 amount);

    event KeysBurned(address indexed vault, uint256 keyId, uint256 amount);
}
