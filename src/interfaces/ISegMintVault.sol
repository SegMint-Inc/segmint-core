// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Vault } from "../types/DataTypes.sol";
import { ISegMintKeys } from "./ISegMintKeys.sol";

/**
 * @title ISegMintVault
 * @notice This contract is a vault that allows users to lock and unlock assets within this
 * contract. It also allows users to bind and unbind keys related to {SegMintKeys}.
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

    /**
     * Emitted when keys are unbinded and burned from a vault.
     * @param vault Address of the vault whose keys have been unbinded.
     * @param keyId Token ID of the unbinded keys.
     * @param amount Number of keys that have been unbind.
     */
    event KeysBurned(address indexed vault, uint256 keyId, uint256 amount);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Function used to initialize the vault.
     * @param owner_ Address of the caller that created the vault.
     * @param keys_ Address of {SegMintKeys} contract.
     */
    function initialize(address owner_, ISegMintKeys keys_) external;

    /**
     * Function used to lock assets within the vault.
     * @param assets Array of assets to lock.
     */
    function lockAssets(Vault.Asset[] calldata assets) external;

    /**
     * Function used to unlock assets from the vault.
     * @param assets Array of assets to lock.
     * @param receiver Receiving address of the assets being unlocked.
     */
    function unlockAssets(Vault.Asset[] calldata assets, address receiver) external;

    /**
     * Function used to unlock Ether from the vault.
     * @param amount Amount of Ether to unlock.
     * @param receiver Receiving address of the unlocked Ether.
     */
    function unlockEther(uint256 amount, address receiver) external;

    /**
     * Function used to bind keys to the vault.
     * @param amount Number of keys to create and bind.
     */
    function bindKeys(uint256 amount) external;

    /**
     * Function used to unbind keys from the vault.
     */
    function unbindKeys() external;
}
