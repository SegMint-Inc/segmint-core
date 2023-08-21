// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { IKeys } from "./IKeys.sol";

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
     * Thrown when trying to unlock an amount of assets that exceeds the movement limit in one transaction.
     */
    error OverMovementLimit();

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
    /*                           ENUMS                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Enum encapsulating the types of assets that can be stored in a multi-asset vault.
     */
    enum MAVAssetClass {
        NONE,
        ERC20,
        ERC721,
        ERC1155
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Struct encapsulating the parameters for multi-asset vault creation.
     * @param class Enum defining the class of the asset.
     * @param token Contract address of the asset.
     * @param identifier Unique token identifier.
     * @param amount The amount of the asset being locked.
     * @dev For ERC721 tokens, the `amount` should always be 1.
     */
    struct MAVAsset {
        MAVAssetClass class;
        address token;
        uint256 identifier;
        uint256 amount;
    }

    /**
     * Struct encapsulating a the key bindings associated with a vault.
     * @param keyId Unique key identifier.
     * @param amount Number of keys associated with a vault.
     */
    struct KeyBinds {
        uint256 keyId;
        uint256 amount;
    }

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
    function unlockAssets(MAVAsset[] calldata assets, address receiver) external;

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
}
