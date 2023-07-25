// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { SegMintVault } from "../SegMintVault.sol";
import { ISegMintSignerModule } from "./ISegMintSignerModule.sol";
import { ISegMintKYCRegistry } from "./ISegMintKYCRegistry.sol";
import { ISegMintKeys } from "./ISegMintKeys.sol";

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
    event VaultCreated(address indexed user, address indexed vault);

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

    /**
     * Emitted when the signer module is updated.
     * @param admin Address of admin that made the update.
     * @param oldSignerModule Previous signer module address.
     * @param newSignerModule New signer module address.
     */
    event SignerModuleUpdated(
        address indexed admin, ISegMintSignerModule oldSignerModule, ISegMintSignerModule newSignerModule
    );

    /**
     * Emitted the keys interface is updated.
     * @param admin Address of admin that made the update.
     * @param oldKeys Previous keys interface address.
     * @param newKeys New keys interface address.
     */
    event KeysUpdated(address indexed admin, ISegMintKeys oldKeys, ISegMintKeys newKeys);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Function used upon upgrade to initialize the appropriate storage variables.
     * @param admin_ Address of the new admin.
     * @param vaultImplementation_ Address of vault implementation.
     * @param signerModule_ Address of {SegMintSignerModule} contract.
     * @param kycRegistry_ Address of {SegMintKYCRegistry} contract.
     */
    function initialize(
        address admin_,
        address vaultImplementation_,
        ISegMintSignerModule signerModule_,
        ISegMintKYCRegistry kycRegistry_
    ) external;

    /**
     * Function used to create a new instance of {SegMintVault}.
     * @param signature Signed message digest.
     */
    function createVault(bytes calldata signature) external;

    /**
     * Function used to view all vaults created by a user.
     * @param account Address to get associated vaults for.
     * @return vaults List of all vaults created by account.
     */
    function getVaults(address account) external view returns (address[] memory);

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

    /**
     * Function used to set a new signer module address.
     * @param newSignerModule The new signer module address.
     */
    function setSignerModule(ISegMintSignerModule newSignerModule) external;

    /**
     * Function used to set a new {SegMintKeys} address.
     * @param newKeys The new {SegMintKeys} address.
     */
    function setKeys(ISegMintKeys newKeys) external;
}
