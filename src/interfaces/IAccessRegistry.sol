// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ISignerRegistry } from "../interfaces/ISignerRegistry.sol";

/**
 * @title IAccessRegistry
 */
interface IAccessRegistry {
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

    /**
     * Thrown when the zero address is provided.
     */
    error ZeroAddressInvalid();

    /**
     * Thrown when the provided nonce has been consumed.
     */
    error NonceUsed();

    /**
     * Thrown when the user address does not match `msg.sender`.
     */
    error UserAddressMismatch();

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
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Struct encapsulating the data related to setting an access type.
     * @param user Account that is being granted the access type.
     * @param deadline The timestamp by which the signature must be used.
     * @param nonce Unique nonce.
     * @param accessType Type of access the user has within the protocol.
     */
    struct AccessParams {
        address user;
        uint256 deadline;
        uint256 nonce;
        AccessType accessType;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Emitted when the access type of an address has been set for the first time.
     * @param account The address whose access type has been set.
     * @param accessType Associated `{AccessType}` Enum.
     * @param signature Signature used for access registration.
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

    /**
     * Emitted when the Signer Registry address is updated.
     * @param oldSignerRegistry Old Signer Registry address.
     * @param newSignerRegistry New Signer Registry address.
     */
    event SignerRegistryUpdated(ISignerRegistry indexed oldSignerRegistry, ISignerRegistry indexed newSignerRegistry);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Function used to initialise the access type of an address.
     * @param accessParams Desired `{AccessParams}` struct.
     * @param signature Signed message digest.
     */
    function initAccessType(AccessParams calldata accessParams, bytes calldata signature) external;

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
     * Function used to view the access type of an address.
     * @param account Account to view the access type for.
     */
    function accessType(address account) external view returns (AccessType);

    /**
     * Function used to view the nonce for a given account.
     * @param account Account to check the nonce for.
     */
    function accountNonce(address account) external view returns (uint256);

    /**
     * Function used to get the `AccessParams` struct hash in accordance with EIP712.
     * @param accessParams Desired `AccessParams` struct.
     */
    function hashAccessParams(AccessParams calldata accessParams) external view returns (bytes32);
}
