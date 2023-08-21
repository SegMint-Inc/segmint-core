// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { IKeys } from "./IKeys.sol";

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
     * Thrown when trying to unlock an asset of class `NONE`.
     */
    error NoneAssetType();

    /**
     * Thrown when trying to lock an ERC721 asset with a value other than 1.
     */
    error Invalid721Amount();

    /**
     * Thrown when trying to lock an asset with a zero amount.
     */
    error ZeroAmountValue();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ENUMS                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Enum encapsulating the types of assets that can be stored in a single-asset vault.
     */
    enum SAVAssetClass {
        NONE,
        ERC721,
        ERC1155
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Struct encapsulating the parameters for single-asset vault creation.
     * @param class Enum defining the class of the asset.
     * @param token Contract address of the asset.
     * @param identifier Unique token identifier.
     * @param amount The amount of the asset being locked.
     * @dev For ERC721 tokens, the `amount` should always be 1.
     */
    struct SAVAsset {
        SAVAssetClass class;
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
     * Function used to initialize vault storage.
     * @param asset_ The asset being locked.
     * @param keys_ Keys contract address.
     * @param keyAmount_ Number of keys being binded.
     * @param receiver_ Receiving address of the newly created keys.
     */
    function initialize(SAVAsset calldata asset_, IKeys keys_, uint256 keyAmount_, address receiver_) external;

    /**
     * Function used to unlock the underlying asset within a vault.
     * @param receiver Address of the account receiving the unlocked asset.
     */
    function unlockAsset(address receiver) external;
}
