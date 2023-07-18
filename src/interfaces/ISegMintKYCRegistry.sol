// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

/**
 * @title ISegMintKYCRegistry
 * @notice Interface for SegMintKYCRegistry.
 */

interface ISegMintKYCRegistry {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ENUMS                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Enum encapsulating the access type related to a specified address.
     * @custom:value NONE: User does not have access.
     * @custom:value RESTRICTED: User has restricted access.
     * @custom:value UNRESTRICTED: User has unrestricted access.
     */
    enum AccessType {
        NONE,
        RESTRICTED,
        UNRESTRICTED
    }

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
    event AccessTypeSet(address indexed account, AccessType accessType);

    /**
     * Emitted when the access type of an address has been modified by an admin.
     * @param admin The address of the admin that made the update.
     * @param account The address whose access type was modified.
     * @param accessType Associated `{ISegMintKYCRegistry.AccessType}` Enum.
     */
    event AccessTypeModified(address indexed admin, address indexed account, AccessType accessType);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Function used to set the access type of an address.
     * @param signature Signed message digest.
     * @param newAccessType Desired `{ISegMintKYCRegistry.AccessType}` Enum value.
     * @dev This function sets the access type of `msg.sender`.
     */
    function setAccessType(bytes calldata signature, AccessType newAccessType) external;

    /**
     * Function used to modify the access type of an address.
     * @param account The address whose access type is being modified.
     * @param newAccessType Desired `{ISegMintKYCRegistry.AccessType}` Enum value.
     */
    function modifyAccessType(address account, AccessType newAccessType) external;

    /**
     * Function used to set a new `_signer` address.
     * @param newSigner Newly desired signer address.
     */
    function setSigner(address newSigner) external;

    /**
     * Function used to view the access type of a specified address.
     * @param account The address whose access type is being queried.
     * @return accessType Returns the access type of the provided address.
     */
    function getAccessType(address account) external view returns (AccessType);
}
