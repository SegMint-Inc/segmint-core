// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { IKeys } from "./IKeys.sol";
import { Asset, KeyConfig } from "../types/DataTypes.sol";

/**
 * @title ISAVault
 * @notice N/A
 */

interface ISAVault {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERRORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Thrown when trying to unlock an asset from a SAV when no asset exists.
     */
    error NoAssetLocked();

    /**
     * Thrown when trying to unlock an asset from a SAV without holding all keys.
     */
    error InsufficientKeys();

    /**
     * Thrown when the asset being locked belongs to the Keys contract.
     */
    error CannotLockKeys();

    /**
     * Thrown when trying to unlock an asset of class `NONE` OR `ERC20`.
     */
    error InvalidAssetType();

    /**
     * Thrown when trying to lock an ERC721 asset with a value other than 1.
     */
    error Invalid721Amount();

    /**
     * Thrown when trying to lock an asset with a zero amount.
     */
    error ZeroAmountValue();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Function used to return the key ID associated with a vault.
     */
    function boundKeyId() external view returns (uint256);

    /**
     * Function used to initialize vault storage.
     * @param _asset Defines the asset being locked.
     * @param _keys Keys contract address.
     * @param _keyAmount Number of keys being binded.
     * @param _receiver Receiving address of the newly created keys.
     */
    function initialize(Asset calldata _asset, IKeys _keys, uint256 _keyAmount, address _receiver) external;

    /**
     * Function used to unlock the underlying asset within a vault.
     * @param receiver Address of the account receiving the unlocked asset.
     */
    function unlockAsset(address receiver) external;

    /**
     * Function used to view the key config associated the vaults key ID.
     */
    function getKeyConfig() external view returns (KeyConfig memory);
}
