// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ISegMintVaultManager } from "./ISegMintVaultManager.sol";

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
    event VaultManagerUpdated(
        address indexed admin, ISegMintVaultManager oldVaultManager, ISegMintVaultManager newVaultManager
    );

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function approveVault(address vault) external;

    function createKeys(uint256 amount, address receiver) external returns (uint256);

    function burnKeys(address holder, uint256 keyId, uint256 amount) external;
}
