// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

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
    /*                   SEGMINT-VAULT-MANAGER                    */
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

    /**
     * Thrown when a predicted address does not match the actual address.
     */
    error AddressMismatch();

    /**
     * Thrown when trying to create a safe with over the maximum number of signers.
     */
    error OverMaxSigners();

    /**
     * Thrown when the quorum amount is greater than the amount of signers.
     */
    error InvalidQuorumValue();

    /**
     * Thrown when trying to lock an asset with an invalid class type.
     */
    error InvalidAssetClass();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       SEGMINT-VAULT                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Thrown when trying to move an excess of assets in one transaction.
     */
    error OverMovementLimit();

    /**
     * Thrown when trying to lock or unlock assets on a key binded vault.
     */
    error KeyBinded();

    /**
     * Thrown when trying to unbind keys on a vault this is not key binded.
     */
    error NotKeyBinded();

    /**
     * Thrown when trying to lock an asset that takes a fee on transfer.
     */
    error FeeOnTransferToken();

    /**
     * Thrown when the transfer of a token fails.
     */
    error TransferFailed();

    /**
     * Thrown when trying to bind an invalid amount of keys to a vault.
     */
    error InvalidKeyAmount();

    /**
     * Thrown when trying to unbind keys on a vault without holding the full key supply.
     */
    error InsufficientKeys();

    /**
     * Thrown when trying to lock keys into a vault.
     */
    error CantLockKeys();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    SEGMINT-VAULT-SINGLE                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Thrown when trying to unlock an asset that doesn't exist.
     */
    error NoAssetLocked();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        SEGMINT-SAFE                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Thrown when duplicate signers are found.
     */
    error DuplicateSigner();

    /**
     * Thrown when an invalid signer address is provided.
     */
    error InvalidSigner();

    /**
     * Thrown when a signer has expired.
     */
    error SignerExpired();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        SEGMINT-KEYS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Thrown when trying to execute a function from an unapproved address.
     */
    error VaultNotApproved();

    /**
     * Thrown when trying to transfer frozen keys.
     */
    error KeysFrozen();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       SIGNER-MANAGER                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Thrown when trying to remove a signer which brings the signer count below the quorum.
     */
    error RemovalBreaksQuorum();

    error InvalidPointer();

    error SignerNotApproved();

    error InvalidCaller();

    /**
     * Thrown when trying to add a signer with an invalid expiry time.
     */
    error InvalidExpiryTime();

    error PointerMismatch();

    error InvalidAssetType();

    error InvalidAssetAmount();

    error InsufficientPayment();

    error WithdrawFailed();
}
