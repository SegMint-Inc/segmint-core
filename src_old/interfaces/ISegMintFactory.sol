// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ISegMintSignerModule } from "./ISegMintSignerModule.sol";
import { ISegMintKYCRegistry } from "./ISegMintKYCRegistry.sol";
import { ISegMintKeys } from "./ISegMintKeys.sol";

/**
 * @title ISegMintFactory
 * @notice This contract is a factory that creates instances of {ISegMintVault} and {ISegMintSafe}
 * using deterministic clones.
 */

interface ISegMintFactory {
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
     * Emitted when a new safe is created.
     * @param user Address of the account that created the safe.
     * @param safe Address of the newly created safe.
     */
    event SafeCreated(address indexed user, address indexed safe);

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
     * @param vaultImplementation_ Address of {SegMintVault} implementation.
     * @param vaultSingleImplementation_ Address of {SegMintVaultSingle} implementation.
     * @param safeImplementation_ Address of {SegMintSafe} implementation.
     * @param signerModule_ Address of {SegMintSignerModule} contract.
     * @param kycRegistry_ Address of {SegMintKYCRegistry} contract.
     * @param keys_ Address of {SegMintKeys} contract.
     */
    function initialize(
        address admin_,
        address vaultImplementation_,
        address vaultSingleImplementation_,
        address safeImplementation_,
        ISegMintSignerModule signerModule_,
        ISegMintKYCRegistry kycRegistry_,
        ISegMintKeys keys_
    ) external;

    /**
     * Function used to create a new instance of {SegMintVault}.
     * @param signature Signed message digest.
     */
    function createVault(bytes calldata signature) external;

    /**
     * Function used to view all vaults created by `account`.
     * @param account Account to view associated vaults for.
     */
    function getVaults(address account) external view returns (address[] memory);

    /**
     * Function used to create a new instance of {SegMintSafe}.
     * @param signature Signed message digest.
     * @param signees Array of addresses that will be added as signers.
     * @param quorum Number of approvals a proposal must have before passing.
     */
    function createSafe(bytes calldata signature, address[] calldata signees, uint256 quorum) external;

    /**
     * Function used to view all safes created by `account`.
     * @param account Account to view associated safe for.
     */
    function getSafes(address account) external view returns (address[] memory);

    /**
     * Function used to propose an upgrade to the implementation address of {SegMintVaultManager}.
     * @param newImplementation Newly proposed {SegMintVaultManager} address.
     */
    function proposeUpgrade(address newImplementation) external;

    /**
     * Function used to cancel a pending upgrade proposal.
     */
    function cancelUpgrade() external;

    /**
     * Function used to execute an upgrade to the implementation address of {SegMintVaultManager}.
     * @param payload Encoded calldata that will be used to initialize the new implementation.
     */
    function executeUpgrade(bytes memory payload) external;
}