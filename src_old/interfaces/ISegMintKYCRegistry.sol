// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ISegMintSignerModule } from "../interfaces/ISegMintSignerModule.sol";
import { KYCRegistry } from "../types/DataTypes.sol";

/**
 * @title ISegMintKYCRegistry
 * @notice Interface for SegMintKYCRegistry.
 */

interface ISegMintKYCRegistry {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Emitted when the signer module is updated.
     * @param admin The address of the admin that made the update.
     * @param oldSignerModule Previous signer module address.
     * @param newSignerModule New signer module address.
     */
    event SignerModuleUpdated(
        address indexed admin, ISegMintSignerModule oldSignerModule, ISegMintSignerModule newSignerModule
    );

    /**
     * Emitted when the access type of an address has been set for the first time.
     * @param account The address whose access type has been set.
     * @param accessType Associated `{ISegMintKYCRegistry.AccessType}` Enum.
     */
    event AccessTypeSet(address indexed account, KYCRegistry.AccessType accessType);

    /**
     * Emitted when the access type of an address has been modified by an admin.
     * @param admin The address of the admin that made the update.
     * @param account The address whose access type was modified.
     * @param oldAccessType Previous `{ISegMintKYCRegistry.AccessType}` Enum value.
     * @param newAccessType New `{ISegMintKYCRegistry.AccessType}` Enum value.
     */
    event AccessTypeModified(
        address indexed admin,
        address indexed account,
        KYCRegistry.AccessType oldAccessType,
        KYCRegistry.AccessType newAccessType
    );

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Function used to initialise the access type of an address.
     * @param signature Signed message digest.
     * @param newAccessType New `{ISegMintKYCRegistry.AccessType}` Enum value.
     * @dev This function sets the access type of `msg.sender`.
     */
    function initAccessType(bytes calldata signature, KYCRegistry.AccessType newAccessType) external;

    /**
     * Function used to modify the access type of an address.
     * @param account The address whose access type is being modified.
     * @param newAccessType Desired `{ISegMintKYCRegistry.AccessType}` Enum value.
     * @dev The role specified represents an administrator role.
     */
    function modifyAccessType(address account, KYCRegistry.AccessType newAccessType) external;

    /**
     * Function used to set a new signer module address.
     * @param newSignerModule The new signer module address.
     */
    function setSignerModule(ISegMintSignerModule newSignerModule) external;

    /**
     * Function used to view the access type of a specified address.
     * @param account The address whose access type is being queried.
     * @return accessType Returns the access type of the provided address.
     */
    function getAccessType(address account) external view returns (KYCRegistry.AccessType);
}
