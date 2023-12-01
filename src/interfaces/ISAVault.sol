// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { IKeys } from "./IKeys.sol";
import { Asset, KeyConfig } from "../types/DataTypes.sol";

/**
 * @title ISAVault
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

    /**
     * Thrown when the zero address is provided.
     */
    error ZeroAddressInvalid();

    /**
     * Thrown when the caller is not the original Vault creator.
     */
    error CallerNotVaultCreator();

    /**
     * Thrown when the input array has zero length.
     */
    error ZeroLengthArray();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Emitted when changes to the delegation rights of an asset are performed.
     * @param delegationHash Unique delegation identifier.
     */
    event DelegationPerformed(bytes32 indexed delegationHash);

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
     * @param _delegateAsset Flag indicating if the underlying asset should be delegated to the Vault creator.
     */
    function initialize(Asset calldata _asset, IKeys _keys, uint256 _keyAmount, address _receiver, bool _delegateAsset) external;

    /**
     * Function used to unlock the underlying asset within a vault.
     * @param receiver Account that will receive the unlocked asset.
     */
    function unlockAsset(address receiver) external;

    /**
     * Function used to modify delegation rights of underlying assets contained within the Vault.
     * @param delegationPayloads Array of encoded delegation calls to make.
     * @dev It is expected that only delegation calls should be made with this function, such as:
     * `delegateAll`, `delegateContract`, `delegateERC721` and `delegateERC1155`.
     */
    function modifyAssetDelegation(bytes[] calldata delegationPayloads) external;

    /**
     * Function used to view the key config associated the vaults key ID.
     */
    function getKeyConfig() external view returns (KeyConfig memory);

    /**
     * Function used to view the specified locked asset associated with the vault.
     */
    function lockedAsset() external view returns (Asset memory);
}
