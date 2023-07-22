// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { SegMintVault } from "../SegMintVault.sol";
import { ISegMintKYCRegistry } from "./ISegMintKYCRegistry.sol";

/**
 * @title ISegMintVaultManager
 * @notice Interface for SegMintVaultManager.
 */

interface ISegMintVaultManager {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Emitted when a new vault is created.
     * @param user Address of the account that created the vault.
     * @param vault Address of the newly created vault.
     */
    event VaultCreated(address indexed user, SegMintVault indexed vault);

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

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Function used to create a new {SegMintVault}.
     * @param signature Signed message digest.
     * @dev `msg.sender` should be the address of the EOA that invoked the creation.
     */
    function createVault(bytes calldata signature) external;

    /**
     * Function used to view all vaults created by a user.
     * @param account The address to get associated vaults for.
     * @return vaults Returns a list of all vaults associated with the account.
     */
    function getVaults(address account) external view returns (SegMintVault[] memory);

    /**
     * Function used upon upgrade to initialize the appropriate storage variables.
     * @param admin_ Address of the new admin.
     * @param signer_ Address of the new signer.
     * @param kycRegistry_ Address of the KYC registry.
     */
    function initialize(address admin_, address signer_, ISegMintKYCRegistry kycRegistry_) external;

    /**
     * Function used to propose an upgrade to the implementation address.
     * @param newImplementation Newly proposed implementation address.
     */
    function proposeUpgrade(address newImplementation) external;

    /**
     * Function used to cancel a pending proposal.
     */
    function cancelUpgrade() external;

    /**
     * Function used to execute an upgrade proposal.
     * @param payload Encoded calldata to make upon implementation upgrade.
     */
    function executeUpgrade(bytes memory payload) external;
}
