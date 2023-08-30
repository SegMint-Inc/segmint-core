// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { IKeys } from "./IKeys.sol";
import { Asset } from "../types/DataTypes.sol";

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
     * Function used to initialize vault storage.
     * @param asset_ The asset being locked.
     * @param keys_ Keys contract address.
     * @param keyAmount_ Number of keys being binded.
     * @param receiver_ Receiving address of the newly created keys.
     */
    function initialize(Asset calldata asset_, IKeys keys_, uint256 keyAmount_, address receiver_) external;

    /**
     * Function used to unlock the underlying asset within a vault.
     * @param receiver Address of the account receiving the unlocked asset.
     */
    function unlockAsset(address receiver) external;
}
