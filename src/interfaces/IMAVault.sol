// SPDX-License-Identifier: SegMint Code License 1.1
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
    error KeysBindedToVault();

    /**
     * Thrown when trying to unbind keys from a non-key binded vault.
     */
    error NoKeysBindedToVault();

    /**
     * Thrown when trying to unlock an asset of class `NONE`.
     */
    error NoneAssetType();

    /**
     * Thrown when the zero address is provided.
     */
    error ZeroAddressInvalid();

    /**
     * Thrown when an input array with zero length is provided.
     */
    error ZeroLengthArray();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Emitted when native token is unlocked.
     * @param receiver Account receiving the native token.
     * @param amount Amount of native token being unlocked.
     */
    event NativeTokenUnlocked(address indexed receiver, uint256 amount);

    /**
     * Emitted when changes to the delegation rights of an asset are performed.
     * @param delegationHash Unique delegation identifier.
     */
    event DelegationPerformed(bytes32 indexed delegationHash);

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
     * @param delegateAssets_ Flag indicating if the underlying assets should be delegated to the Vault creator.
     */
    function initialize(address owner_, IKeys keys_, uint256 keyAmount_, bool delegateAssets_) external;

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
     * Function used to modify delegation rights of underlying assets contained within the Vault.
     * @param delegationPayloads Array of encoded delegation calls to make.
     * @dev It is expected that only delegation calls should be made with this function, such as:
     * `delegateAll`, `delegateContract`, `delegateERC20`, `delegateERC721` and `delegateERC1155`.
     */
    function modifyAssetDelegation(bytes[] calldata delegationPayloads) external;

    /**
     * Function used to view the key config associated the vaults key ID.
     */
    function getKeyConfig() external view returns (KeyConfig memory);
}
