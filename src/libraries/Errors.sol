// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

/**
 * @title Errors
 * @notice Library containing all custom errors that the protocol may revert with.
 */
library Errors {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       GENERIC ERRORS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Thrown when a recovered signer address does not match the expected signer address.
     */
    error SignerMismatch();

    /**
     * Thrown when an input array of zero length is provided.
     */
    error ZeroLengthArray();

    /**
     * Thrown when a user tries to initialize an address with an access type of `BLOCKED`.
     */
    error InvalidAccessType();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    SEGMINT-KYC-REGISTRY                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Thrown when a user tries to set the access type of an already initialized address.
     */
    error AccessTypeSet();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       SEGMINT-LOCKER                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   SEGMINT-LOCKER-FACTORY                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   SEGMINT-VAULT-REGISTRY                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Thrown when trying to initiate an upgrade proposal while one is in progress.
     */
    error ProposalInProgress();

    /**
     * Thrown when trying to cancel an upgrade proposal that doesn't exist.
     */
    error NoProposalExists();

    /**
     * Thrown when trying to execute an upgrade before the time lock has expired.
     */
    error UpgradeTimeLocked();

    /**
     * Thrown when trying to execute an upgrade without the correct permissions.
     */
    error Unauthorized();
}
