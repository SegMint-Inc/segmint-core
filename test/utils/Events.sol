// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ISignerRegistry } from "../../src/interfaces/ISignerRegistry.sol";
import { IKYCRegistry } from "../../src/interfaces/IKYCRegistry.sol";
import { IKeyExchange } from "../../src/interfaces/IKeyExchange.sol";
import { IVaultFactory } from "../../src/interfaces/IVaultFactory.sol";
import { IKeys } from "../../src/interfaces/IKeys.sol";
import { OperatorFilter } from "../../src/handlers/OperatorFilter.sol";
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
    event OrderFilled(bytes32 orderHash);
    event BidFilled(bytes32 bidHash);
    event OrderCancelled(bytes32 orderHash);
    event BidCancelled(bytes32 bidHash);

    /// {IVaultFactory} Events.
    event VaultCreated(address indexed user, address indexed vault, VaultType vaultType);
    event SafeCreated(address indexed user, address indexed safe);

    /// {IKeys} Events.
    event KeyFrozen(address indexed admin, uint256 keyId);
    event KeyUnfrozen(address indexed admin, uint256 keyId);

    /// {IUpgradeHandler} Events.
    event UpgradeProposed(address indexed admin, address implementation, uint40 deadline);
    event UpgradeCancelled(address indexed admin, address implementation);

    /// {OperatorFilter} Events.
    event OperatorStatusUpdated(address operator, bool status);
}
