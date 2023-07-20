// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

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
     * Emitted when the signer address is updated.
     * @param admin The admin address that made the update.
     * @param oldSigner The previous signer address.
     * @param newSigner The new signer address.
     */
    event SignerUpdated(address indexed admin, address oldSigner, address newSigner);

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
     * @param accessType Associated `{ISegMintKYCRegistry.AccessType}` Enum.
     */
    event AccessTypeModified(address indexed admin, address indexed account, KYCRegistry.AccessType accessType);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Function used to initialise the access type of an address.
     * @param signature Signed message digest.
     * @param newAccessType Desired `{ISegMintKYCRegistry.AccessType}` Enum value.
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
     * Function used to set a new `_signer` address.
     * @param newSigner Newly desired signer address.
     * @dev The role specified represents an administrator role.
     */
    function setSigner(address newSigner) external;

    /**
     * Function used to view the current signer address.
     * @return signer Returns the current signer address.
     */
    function signer() external view returns (address);

    /**
     * Function used to view the access type of a specified address.
     * @param account The address whose access type is being queried.
     * @return accessType Returns the access type of the provided address.
     */
    function getAccessType(address account) external view returns (KYCRegistry.AccessType);
}
