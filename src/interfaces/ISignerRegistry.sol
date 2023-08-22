// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * @title ISignerRegistry
 * @notice This contract is responsible for returning the current signer address. Since this
 * address is used across a variety of different contracts within the ecosystem, I have opted
 * to use a registry as a single source of information.
 */

interface ISignerRegistry {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERRORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Thrown when the recovered signer address does not match the expected signer address.
     */
    error SignerMismatch();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Emitted when the signer address is updated.
     * @param admin Address of the admin that updated the signer address.
     * @param oldSigner Previous signer address.
     * @param newSigner New signer address.
     */
    event SignerUpdated(address indexed admin, address oldSigner, address newSigner);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Function used to set a new signer address.
     * @param newSigner Newly desired signer address.
     */
    function setSigner(address newSigner) external;

    /**
     * Function used to get the current signer address.
     */
    function getSigner() external view returns (address);
}