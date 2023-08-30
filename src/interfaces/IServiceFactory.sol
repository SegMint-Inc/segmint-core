// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ISignerRegistry } from "./ISignerRegistry.sol";
import { IKYCRegistry } from "./IKYCRegistry.sol";
import { ISAVault } from "./ISAVault.sol";
import { IKeys } from "./IKeys.sol";
import { Asset } from "../types/DataTypes.sol";

/**
 * @title IServiceFactory
 * @notice N/A
 */

interface IServiceFactory {
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
     */
    event VaultCreated(address indexed user, address indexed vault);

    /**
     * Emitted when a new safe is created.
     * @param user Address of the account that created the safe.
     * @param safe Address of the newly created safe.
     */
    event SafeCreated(address indexed user, address indexed safe);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Function used to initialize {ServiceFactory}.
     * @param admin_ Address to asign the admin role.
     * @param mavImplementation_ Address of multi-asset vault implementation.
     * @param savImplementation_ Address of single-asset vault implementation.
     * @param safeImplementation_ Address of safe implementation.
     * @param signerRegistry_ Address of signer registry.
     * @param kycRegistry_ Address of KYC registry.
     * @param keys_ Address of keys.
     */
    function initialize(
        address admin_,
        address mavImplementation_,
        address savImplementation_,
        address safeImplementation_,
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
     * Function used to create a safe.
     * @param signers List of signer addresses to initialize the safe with.
     * @param quorum Initial quorum value that all proposals must reach.
     * @param signature Signed message digest.
     */
    function createSafe(address[] calldata signers, uint256 quorum, bytes calldata signature) external;

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
     * Function used to get all the safes created by a given account.
     * @param account Address of the account to check.
     */
    function getSafes(address account) external view returns (address[] memory);

    /**
     * Function used to propose an upgrade to the implementation address of {ServiceFactory}.
     * @param newImplementation Newly proposed {ServiceFactory} address.
     */
    function proposeUpgrade(address newImplementation) external;

    /**
     * Function used to cancel a pending upgrade proposal.
     */
    function cancelUpgrade() external;

    /**
     * Function used to execute an upgrade to the implementation address of {ServiceFactory}.
     * @param payload Encoded calldata that will be used to initialize the new implementation.
     */
    function executeUpgrade(bytes memory payload) external;
}
