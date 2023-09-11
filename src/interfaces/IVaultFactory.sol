// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import { ISignerRegistry } from "./ISignerRegistry.sol";
import { IKYCRegistry } from "./IKYCRegistry.sol";
import { ISAVault } from "./ISAVault.sol";
import { IKeys } from "./IKeys.sol";
import { Asset, VaultType } from "../types/DataTypes.sol";

/**
 * @title IVaultFactory
 * @notice N/A
 */

interface IVaultFactory {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERRORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Thrown when the predicted deployment address does not match the actual deployment address.
     */
    error AddressMismatch();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Emitted when a new vault is created.
     * @param user Address of the account that created the vault.
     * @param vault Address of the newly created vault.
     * @param vaultType The type of vault created.
     */
    event VaultCreated(address indexed user, address indexed vault, VaultType vaultType);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Function used to initialize {VaultFactory}.
     * @param admin_ Address to asign the admin role.
     * @param maVault_ Multi asset vault implementation.
     * @param saVault_ Single asset vault implementation.
     * @param signerRegistry_ Address of signer registry.
     * @param kycRegistry_ Address of KYC registry.
     * @param keys_ Address of keys.
     */
    function initialize(
        address admin_,
        address maVault_,
        address saVault_,
        ISignerRegistry signerRegistry_,
        IKYCRegistry kycRegistry_,
        IKeys keys_
    ) external;

    /**
     * Function used to create a multi-asset vault.
     * @param signature Signed message digest.
     */
    function createMultiAssetVault(bytes calldata signature) external;

    /**
     * Function used to create a single-asset vault.
     * @param asset The asset being locked and fractionalized.
     * @param keyAmount Number of keys to create and bind.
     * @param signature Signed message digest.
     */
    function createSingleAssetVault(Asset calldata asset, uint256 keyAmount, bytes calldata signature) external;

    /**
     * Function used to get all the multi-asset vaults created by a given account.
     * @param account Address of the account to check.
     */
    function getMultiAssetVaults(address account) external view returns (address[] memory);

    /**
     * Function used to get all the single-asset vaults created by a given account.
     * @param account Address of the account to check.
     */
    function getSingleAssetVaults(address account) external view returns (address[] memory);

    /**
     * Function used to view the current nonces associated with a given account for each vault type.
     * @param account Address of the account to check.
     */
    function getNonces(address account) external view returns (uint256, uint256);

    /**
     * Function used to propose an upgrade to the implementation address of {VaultFactory}.
     * @param newImplementation Newly proposed {VaultFactory} address.
     */
    function proposeUpgrade(address newImplementation) external;

    /**
     * Function used to cancel a pending upgrade proposal.
     */
    function cancelUpgrade() external;

    /**
     * Function used to execute an upgrade to the implementation address of {VaultFactory}.
     * @param payload Encoded calldata that will be used to initialize the new implementation.
     */
    function executeUpgrade(bytes memory payload) external;

    /**
     * Function used to view the current name and version of the Vault Factory.
     */
    function nameAndVersion() external view returns (string memory, string memory);
}
