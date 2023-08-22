// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ISegMintKeys } from "./ISegMintKeys.sol";
import { Keys, Vault } from "../types/DataTypes.sol";

/**
 * @title ISegMintVault
 * @notice This contract allows a user to lock a single ERC-721 or ERC-1155 asset into
 * a vault. Users are also able to bind and unbind keys associated with {SegMintKeys}.
 */

interface ISegMintVaultSingle {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

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

    // /**
    //  * Function used to initialize the vault.
    //  * @param owner_ Address of the caller that created the vault.
    //  * @param keys_ Address of {SegMintKeys} contract.
    //  * @param asset_ Asset being locked into the vault.
    //  */
    // function initialize(address owner_, ISegMintKeys keys_, Vault.Asset calldata asset_) external;
    function initialize(ISegMintKeys keys_, Vault.Asset calldata asset_, Keys.Bindings calldata keyBindings_)
        external;

    /**
     * Function used to unlock assets from the vault.
     * @param receiver Receiving address of the assets being unlocked.
     */
    function unlockAsset(address receiver) external;
}