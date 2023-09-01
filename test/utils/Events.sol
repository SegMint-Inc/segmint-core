// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ISignerRegistry } from "../../src/interfaces/ISignerRegistry.sol";
import { IKYCRegistry } from "../../src/interfaces/IKYCRegistry.sol";
import { IKeyExchange } from "../../src/interfaces/IKeyExchange.sol";
import { IServiceFactory } from "../../src/interfaces/IServiceFactory.sol";
import { IKeys } from "../../src/interfaces/IKeys.sol";
import { VaultType } from "../../src/types/DataTypes.sol";

abstract contract Events {
    /// {ISignerRegistry} Events.
    event SignerUpdated(address indexed admin, address oldSigner, address newSigner);

    /// {IKYCRegistry} Events.
    event AccessTypeSet(address indexed account, IKYCRegistry.AccessType accessType, bytes signature);
    event AccessTypeModified(
        address indexed admin,
        address indexed account,
        IKYCRegistry.AccessType oldAccessType,
        IKYCRegistry.AccessType newAccessType
    );

    /// {IKeyExchange} Events.
    event OrderIsFilled();
    event OrderCancelled(bytes32 orderHash);

    /// {IServiceFactory} Events.
    event VaultCreated(address indexed user, address indexed vault, VaultType vaultType);
    event SafeCreated(address indexed user, address indexed safe);

    /// {IKeys} Events.
    event KeyFrozen(address indexed admin, uint256 keyId);
    event KeyUnfrozen(address indexed admin, uint256 keyId);
}
