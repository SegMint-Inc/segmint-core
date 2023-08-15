// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ISegMintFactory } from "./ISegMintFactory.sol";
import { Vault } from "../types/DataTypes.sol";

/**
 * @title ISegMintKeys
 * @notice Interface for SegMintKeys.
 */

interface ISegMintKeys {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Emitted when a new vault is approved.
     * @param vault Address of the approved vault.
     */
    event VaultApproved(address indexed vault);

    /**
     * Emitted when the vault manager is updated.
     * @param admin Address of the admin that made the update.
     * @param oldVaultManager Previous vault manager address.
     * @param newVaultManager New vault manager address.
     */
    event VaultManagerUpdated(address indexed admin, ISegMintFactory oldVaultManager, ISegMintFactory newVaultManager);

    /**
     * Emitted when a specified group of keys is frozen.
     * @param admin Address of the admin that froze the keys.
     * @param keyId Key identifier that was frozen.
     */
    event KeyFrozen(address indexed admin, uint256 keyId);

    /**
     * Emitted when a specified group of keys is unfrozen.
     * @param admin Address of the admin that unfroze the keys.
     * @param keyId Key ID that was unfrozen.
     */
    event KeyUnfrozen(address indexed admin, uint256 keyId);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function approveVault(address vault) external;

    function createKeys(uint256 amount, address receiver, Vault.KeyType keyType) external returns (uint256);

    function burnKeys(address holder, uint256 keyId, uint256 amount) external;
}
