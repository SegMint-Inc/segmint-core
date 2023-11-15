// SPDX-License-Identifier: SegMint Code License 1.1
pragma solidity 0.8.19;

/**
 * @title IUpgradeHandler
 */
interface IUpgradeHandler {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERRORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Thrown when trying to create a new upgrade proposal whilst one is already in progress.
     */
    error ProposalInProgress();

    /**
     * Thrown when trying to cancel an upgrade proposal when one doesn't exist.
     */
    error NoProposalExists();

    /**
     * Thrown when trying to execute an upgrade propsal before the timelock period has lapsed.
     */
    error UpgradeTimeLocked();

    /**
     * Thrown when trying to execute an upgrade via {UUPSUpgradeable.upgradeTo} or {UUPSUpgradeable.upgradeToAndCall}.
     */
    error UpgradeMethodBlocked();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Struct encapsulating a proposal to upgrade the implementation address.
     * @param newImplementation Newly proposed implementation address.
     * @param deadline Timestamp of when the upgrade proposal can be executed.
     */
    struct UpgradeProposal {
        address newImplementation;
        uint40 deadline;
    }

    /**
     * Emitted when a new implementation address for {SegMintVaultManager} has been proposed.
     * @param admin The admin address that proposed the upgrade.
     * @param implementation The newly proposed implementation address.
     * @param deadline Timestamp of when the upgrade proposal can be executed.
     */
    event UpgradeProposed(address indexed admin, address implementation, uint40 deadline);

    /**
     * Emitted when a proposed upgrade is cancelled.
     * @param admin The admin address that cancelled the upgrade.
     * @param implementation The cancelled implementation address.
     */
    event UpgradeCancelled(address indexed admin, address implementation);
}
