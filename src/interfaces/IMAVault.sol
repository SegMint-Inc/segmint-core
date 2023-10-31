// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { IKeys } from "./IKeys.sol";
import { Asset, KeyConfig } from "../types/DataTypes.sol";

/**
 * @title IMAVault
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
     * Thrown when a native token unlock transfer fails.
     */
    error NativeTokenUnlockFailed();

    /**
     * Thrown when trying to bind keys to an already key binded vault.
     */
    error KeysBinded();

    /**
     * Thrown when trying to unbind keys from a non-key binded vault.
     */
    error NoKeysBinded();

    /**
     * Thrown when trying to unlock an asset of class `NONE`.
     */
    error NoneAssetType();

    /**
     * Thrown when the zero address is provided.
     */
    error ZeroAddressInvalid();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Function used to return the key ID associated with a vault.
     */
    function boundKeyId() external view returns (uint256);

    /**
     * Function used to initialize the vault.
     * @param owner_ Address of the caller that created the vault.
     * @param keys_ Address of {SegMintKeys} contract.
     * @param keyAmount_ Number of keys to bind to the vault.
     */
    function initialize(address owner_, IKeys keys_, uint256 keyAmount_) external;

    /**
     * Function used to unlock assets from the vault.
     * @param assets Array of assets to lock.
     * @param receiver Receiving address of the assets being unlocked.
     */
    function unlockAssets(Asset[] calldata assets, address receiver) external;

    /**
     * Function used to unlock the Native Token from the vault.
     * @param receiver Receiving address of the unlocked Ether.
     */
    function unlockNativeToken(address receiver) external;

    /**
     * Function used to claim ownership of the vault, enabling asset and native token unlocking.
     */
    function claimOwnership() external;

    /**
     * Function used to view the key config associated the vaults key ID.
     */
    function getKeyConfig() external view returns (KeyConfig memory);
}
