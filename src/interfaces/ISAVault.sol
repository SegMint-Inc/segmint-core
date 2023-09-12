// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IKeys } from "./IKeys.sol";
import { Asset, KeyConfig } from "../types/DataTypes.sol";

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
    error ZeroAssetAmount();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Function used to view the key ID associated with the vault.
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
     * @param receiver Account that will receive the unlocked asset.
     */
    function unlockAsset(address receiver) external;

    /**
     * Function used to view the key config associated the vaults key ID.
     */
    function getKeyConfig() external view returns (KeyConfig memory);

    /**
     * Function used to view the specified locked asset associated with the vault.
     */
    function lockedAsset() external view returns (Asset memory);
}
