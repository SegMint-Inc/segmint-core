// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ISignerManager {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERRORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Thrown when trying to add a signer that is deemed as invalid.
     */
    error InvalidSigner();

    /**
     * Thrown when attempting to add a signer that already exists.
     */
    error DuplicateSigner();

    /**
     * Thrown when the newly proposed quorum value exceeds the number of signers.
     */
    error RemovalBreaksQuorum();

    /**
     * Thrown when the pointer signer does point to the expected signer.
     */
    error InvalidPointer();

    /**
     * Thrown when the pointer signer does not match the expected signer.
     */
    error PointerMismatch();

    /**
     * Thrown when an invalid quorum value is provided.
     */
    error InvalidQuorumValue();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Function used to remove a signer and update the quorum value.
     * @param ptrSigner Signer address that points to `signer` in the linked list.
     * @param signer Address of the signer to be removed.
     * @param quorumValue Number of signer approvals to reach quorum on a proposal.
     */
    function removeSigner(address ptrSigner, address signer, uint256 quorumValue) external;

    /**
     * Function used to add a signer and update the quorum value.
     * @param newSigner Address of the new signer to be added.
     * @param quorumValue Number of signer approvals to reach quorum on a proposal.
     */
    function addSigner(address newSigner, uint256 quorumValue) external;

    /**
     * Function used to swap `oldSigner` with `newSigner` and update the quorum value.
     * @param ptrSigner Signer address that points to `signer` in the linked list.
     * @param oldSigner Address of the old signer to be removed.
     * @param newSigner Address of the new signer to be added.
     */
    function swapSigner(address ptrSigner, address oldSigner, address newSigner) external;

    /**
     * Function used to update the quorum value.
     * @param quorumValue New number of approvals required to reach quorum on a proposal.
     */
    function updateQuorum(uint256 quorumValue) external;

    /**
     * Function used to view all the approved signers of a Safe.
     */
    function getSigners() external view returns (address[] memory);

    /**
     * Function used to view if `account` is an approved signer.
     */
    function isSigner(address account) external view returns (bool);

    /**
     * Function used to view the current quorum value.
     */
    function quorum() external view returns (uint256);
}
