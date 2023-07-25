// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Vault } from "../types/DataTypes.sol";
import { ISegMintKeys } from "./ISegMintKeys.sol";

/**
 * @title ISegMintVault
 * @notice Interface for SegMintVault.
 */

interface ISegMintVault {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Emitted when keys are created and binded to a vault.
     * @param vault Address of the vault in which keys have been binded to.
     * @param keyId Token ID of the newly binded keys.
     * @param amount Number of keys that have been binded.
     */
    event KeysCreated(address indexed vault, uint256 keyId, uint256 amount);

    event KeysBurned(address indexed vault, uint256 keyId, uint256 amount);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Function used to initialize a vault clone.
     * @param owner_ Address of the vault owner.
     * @param keys_ Interface for {SegMintKeys} contract.
     */
    function initialize(address owner_, ISegMintKeys keys_) external;

    /**
     * Function used to view the current {ISegMintKeys} address.
     * @return keys Returns the current {ISegMintKeys} address.
     */
    function keys() external view returns (ISegMintKeys);

    /**
     * Function used to lock assets within a vault.
     * @param assets Array of desired assets to lock.
     */
    function lockAssets(Vault.Asset[] calldata assets) external;

    /**
     * Function used to unlock assets within a vault.
     * @param assets Array of desired assets to lock.
     * @param receiver Receiving address of the assets.
     */
    function unlockAssets(Vault.Asset[] calldata assets, address receiver) external;

    /**
     * Function used to bind keys to a vault.
     * @param amount Number of keys to bind.
     */
    function bindKeys(uint256 amount) external;

    /**
     * Function used to unbind keys from a vault.
     */
    function unbindKeys() external;

    /**
     * Function used to unlock Ether from a vault.
     * @param amount Amount of Ether to unlock.
     * @param receiver Receiving address of the Ether.
     */
    function unlockEther(uint256 amount, address receiver) external;
}
