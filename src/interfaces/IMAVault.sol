// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IKeys } from "./IKeys.sol";
import { Asset, KeyConfig } from "../types/DataTypes.sol";

/**
 * @title IMAVault
 * @notice N/A
 */

interface IMAVault {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERRORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Thrown when trying to unlock a zero amount of assets.
     */
    error ZeroAssetAmount();

    /**
     * Thrown when trying to unlock an asset from a MAV without holding all keys.
     */
    error InsufficientKeys();

    /**
     * Thrown when a native token unlock transfer fails.
     */
    error NativeTokenUnlockFailed();

    /**
     * Thrown when trying to bind keys to an already key binded vault.
     */
    error KeysAlreadyBinded();

    /**
     * Thrown when trying to unbind keys from a non-key binded vault.
     */
    error NoKeysBinded();

    /**
     * Thrown when trying to unlock an asset of class `NONE`.
     */
    error NoneAssetType();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Function used to initialize the vault.
     * @param owner_ Address of the caller that created the vault.
     * @param keys_ Address of {SegMintKeys} contract.
     */
    function initialize(address owner_, IKeys keys_) external;

    /**
     * Function used to unlock assets from the vault.
     * @param assets Array of assets to lock.
     * @param receiver Receiving address of the assets being unlocked.
     */
    function unlockAssets(Asset[] calldata assets, address receiver) external;

    /**
     * Function used to unlock the Native Token from the vault.
     * @param amount Amount of Ether to unlock.
     * @param receiver Receiving address of the unlocked Ether.
     */
    function unlockNativeToken(uint256 amount, address receiver) external;

    /**
     * Function used to bind keys to the vault.
     * @param keyAmount Number of keys to create and bind.
     */
    function bindKeys(uint256 keyAmount) external;

    /**
     * Function used to unbind keys from the vault.
     */
    function unbindKeys() external;

    /**
     * Function used to view the key config associated the vaults key ID.
     */
    function getKeyConfig() external view returns (KeyConfig memory);

    /**
     * Function used to return the key ID associated with a vault.
     */
    function boundKeyId() external view returns (uint256);
}
