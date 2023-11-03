// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ISignerRegistry } from "../../src/interfaces/ISignerRegistry.sol";
import { IAccessRegistry } from "../../src/interfaces/IAccessRegistry.sol";
import { IKeyExchange } from "../../src/interfaces/IKeyExchange.sol";
import { IVaultFactory } from "../../src/interfaces/IVaultFactory.sol";
import { IMAVault } from "../../src/interfaces/IMAVault.sol";
import { IKeys } from "../../src/interfaces/IKeys.sol";
import { OperatorFilter } from "../../src/handlers/OperatorFilter.sol";
import { VaultType } from "../../src/types/DataTypes.sol";

abstract contract Events {
    /// {ISignerRegistry} Events.
    event SignerUpdated(address indexed admin, address oldSigner, address newSigner);

    /// {IAccessRegistry} Events.
    event AccessTypeSet(address indexed account, IAccessRegistry.AccessType accessType, bytes signature);
    event AccessTypeModified(
        address indexed admin,
        address indexed account,
        IAccessRegistry.AccessType oldAccessType,
        IAccessRegistry.AccessType newAccessType
    );
    event SignerRegistryUpdated(ISignerRegistry indexed oldSignerRegistry, ISignerRegistry indexed newSignerRegistry);

    /// {IKeyExchange} Events.
    event OrderFilled(bytes32 orderHash);
    event BidFilled(bytes32 bidHash);
    event OrderCancelled(bytes32 orderHash);
    event BidCancelled(bytes32 bidHash);
    event BuyOutExecuted(address indexed caller, uint256 indexed keyId);
    event ReserveBuyOut(address indexed caller, uint256 indexed keyId);
    event ProtocolFeeUpdated(uint256 oldFee, uint256 newFee);
    event KeyTermsSet(uint256 indexed keyId, IKeyExchange.KeyTerms keyTerms);
    event MultiKeyTradingUpdated(bool newStatus);
    event RestrictedUserAccessUpdated(bool newStatus);
    event FeeReceiverUpdated(address oldFeeReceiver, address newFeeReceiver);

    /// {IVaultFactory} Events.
    event VaultCreated(address indexed user, address indexed vault, VaultType vaultType);
    event SafeCreated(address indexed user, address indexed safe);

    /// {IKeys} Events.
    event KeyFrozen(address indexed admin, uint256 indexed keyId);
    event KeyUnfrozen(address indexed admin, uint256 indexed keyId);
    event VaultRegistered(address indexed registeredVault);
    event KeyExchangeUpdated(address indexed oldKeyExchange, address indexed newKeyExchange);
    event URIUpdated(string newURI);
    event AccessRegistryUpdated(IAccessRegistry indexed oldAccessRegistry, IAccessRegistry indexed newAccessRegistry);

    /// {IUpgradeHandler} Events.
    event UpgradeProposed(address indexed admin, address implementation, uint40 deadline);
    event UpgradeCancelled(address indexed admin, address implementation);

    /// {OperatorFilter} Events.
    event OperatorStatusUpdated(address operator, bool status);

    /// {IMAVault} Events.
    event NativeTokenUnlocked(address indexed receiver, uint256 amount);
}
