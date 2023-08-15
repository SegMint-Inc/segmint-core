// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * @title ISegMintSignerModule
 * @notice This contract is responsible for returning the current signer address.
 */

interface ISegMintSignerModule {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Emitted when the signer address is updated.
     * @param admin Admin address that made the update.
     * @param oldSigner Previous signer address.
     * @param newSigner New signer address.
     */
    event SignerUpdated(address indexed admin, address oldSigner, address newSigner);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Function used to set a new `_signer` address.
     * @param newSigner Newly desired signer address.
     * @dev The role specified represents an administrator role.
     */
    function setSigner(address newSigner) external;

    /**
     * Function used to view the current `_signer` address.
     * @return signer Returns the current `_signer` address.
     */
    function getSigner() external view returns (address);
}
