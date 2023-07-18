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

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    SEGMINT-KYC-REGISTRY                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Thrown when a user tries to set the access type of an already initialized address.
     */
    error AccessTypeSet();

    /**
     * Thrown when a user tries to initialize an address with an access type of `NONE`.
     */
    error NoneAccessType();
}
