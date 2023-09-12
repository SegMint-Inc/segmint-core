// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ISignerRegistry } from "../interfaces/ISignerRegistry.sol";

/**
 * @title IKYCRegistry
 * @notice This contract returns the access type associated with a given address on-chain. Users
 * will be able to initialize their access type once they have KYC'd on the SegMint platform.
 */

interface IKYCRegistry {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERRORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Thrown when a user tries to define an access type for an already defined address.
     */
    error AccessTypeDefined();

    /**
     * Thrown when a user tries to set an access type with the default value.
     */
    error InvalidAccessType();

    /**
     * Thrown when a user tries to use an expired signature when initializing their access type.
     */
    error DeadlinePassed();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ENUMS                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Enum encapsulating the access type related to a specified address.
     * @custom:value BLOCKED: User does not have access.
     * @custom:value RESTRICTED: User has restricted access.
     * @custom:value UNRESTRICTED: User has unrestricted access.
     */
    enum AccessType {
        BLOCKED,
        RESTRICTED,
        UNRESTRICTED
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Emitted when the access type of an address has been set for the first time.
     * @param account The address whose access type has been set.
     * @param accessType Associated `{AccessType}` Enum.
     * @param signature Signature used for KYC registration.
     */
    event AccessTypeSet(address indexed account, AccessType accessType, bytes signature);

    /**
     * Emitted when the access type of an address has been modified by an admin.
     * @param admin The address of the admin that made the update.
     * @param account The address whose access type was modified.
     * @param oldAccessType Previous `{AccessType}` Enum value of account.
     * @param newAccessType New `{AccessType}` Enum value for account.
     */
    event AccessTypeModified(
        address indexed admin, address indexed account, AccessType oldAccessType, AccessType newAccessType
    );

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Function used to initialise the access type of an address.
     * @param signature Signed message digest.
     * @param deadline Timestamp of when the signature expires.
     * @param newAccessType New `{AccessType}` Enum value.
     */
    function initAccessType(bytes calldata signature, uint256 deadline, AccessType newAccessType) external;

    /**
     * Function used to modify the access type of an address.
     * @param account The address whose access type is being modified.
     * @param newAccessType Desired `{AccessType}` Enum value.
     */
    function modifyAccessType(address account, AccessType newAccessType) external;

    /**
     * Function used to set a new signer module address.
     * @param newSignerRegistry The new signer registry address.
     */
    function setSignerRegistry(ISignerRegistry newSignerRegistry) external;

    /**
     * Function used to view the access type of an address
     */
    function accessType(address account) external view returns (AccessType);
}
