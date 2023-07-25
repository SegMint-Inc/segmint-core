// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { OwnableRoles } from "solady/src/auth/OwnableRoles.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";
import { LibClone } from "solady/src/utils/LibClone.sol";
import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/proxy/utils/UUPSUpgradeable.sol";
import { ISegMintVaultManager } from "./interfaces/ISegMintVaultManager.sol";
import { ISegMintVault } from "./interfaces/ISegMintVault.sol";
import { ISegMintKYCRegistry } from "./interfaces/ISegMintKYCRegistry.sol";
import { ISegMintSignerModule } from "./interfaces/ISegMintSignerModule.sol";
import { ISegMintKeys } from "./interfaces/ISegMintKeys.sol";
import { Errors } from "./libraries/Errors.sol";
import { KYCRegistry, Vault, VaultManager } from "./types/DataTypes.sol";

/**
 * TODO: Implement clones for vault creation using CREATE2.
 */

contract SegMintVaultManager is ISegMintVaultManager, OwnableRoles, Initializable, UUPSUpgradeable {
    using ECDSA for bytes32;
    using LibClone for address;

    /// @dev Upgrade proposals cannot be executed for 5 days.
    uint256 private constant _UPGRADE_TIMELOCK = 5 days;

    ISegMintSignerModule public signerModule;
    ISegMintKYCRegistry public kycRegistry;
    ISegMintKeys public keys;

    VaultManager.UpgradeProposal public upgradeProposal;

    address public vaultImplementation;

    mapping(address account => uint256 nonce) private _nonces;

    function initialize(
        address admin_,
        address vaultImplementation_,
        ISegMintSignerModule signerModule_,
        ISegMintKYCRegistry kycRegistry_
    ) external initializer {
        _initializeOwner(msg.sender);
        _grantRoles(admin_, _ROLE_0);

        vaultImplementation = vaultImplementation_;

        signerModule = signerModule_;
        kycRegistry = kycRegistry_;
    }

    /**
     * @inheritdoc ISegMintVaultManager
     * @dev `msg.sender` will be the EOA that invoked the vault creation.
     */
    function createVault(bytes calldata signature) external override {
        /// Checks: Ensure the `keys` address has been set.
        if (address(keys) == address(0)) revert Errors.KeysNotSet();

        /// Checks: Ensure the caller has access.
        KYCRegistry.AccessType accessType = kycRegistry.getAccessType(msg.sender);
        if (accessType == KYCRegistry.AccessType.BLOCKED) revert Errors.InvalidAccessType();

        /// Checks: Ensure the provided signature is valid.
        bytes32 digest = keccak256(abi.encodePacked(msg.sender, accessType, "CREATE_VAULT"));
        address recoveredSigner = digest.toEthSignedMessageHash().recover(signature);
        if (signerModule.getSigner() != recoveredSigner) revert Errors.SignerMismatch();

        /// Cache current nonce and increment.
        uint256 currentNonce = _nonces[msg.sender]++;

        /// Caclulate CREATE2 salt.
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, currentNonce));

        /// Sanity check to confirm the predicted address matches the actual addresses.
        /// This is done prior to any further storage updates. If this statement ever
        /// fails, chaos ensues.
        address predictedVault = vaultImplementation.predictDeterministicAddress(salt, address(this));
        address newVault = vaultImplementation.cloneDeterministic(salt);
        if (predictedVault != newVault) revert Errors.AddressMismatch();

        /// Initialize the newly created clone.
        ISegMintVault(newVault).initialize(msg.sender, keys);

        /// Approve the newly created vault with the keys contract to allow for
        /// further interactions with `keys` to be decoupled from this contract.
        keys.approveVault(predictedVault);

        /// Emit vault creation event.
        emit VaultCreated({ user: msg.sender, vault: newVault });
    }

    /**
     * @inheritdoc ISegMintVaultManager
     */
    function getVaults(address account) external view returns (address[] memory) {
        uint256 length = _nonces[account];
        address[] memory vaults = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            bytes32 salt = keccak256(abi.encodePacked(account, i));
            vaults[i] = vaultImplementation.predictDeterministicAddress(salt, address(this));
        }

        return vaults;
    }

    /**
     * @inheritdoc ISegMintVaultManager
     */
    function proposeUpgrade(address newImplementation) external override onlyRoles(_ROLE_0) {
        /// Checks: Ensure that a proposal is not currently in progress.
        if (upgradeProposal.deadline != 0) revert Errors.ProposalInProgress();

        uint40 proposalDeadline = uint40(block.timestamp + _UPGRADE_TIMELOCK);

        /// forgefmt: disable-next-item
        upgradeProposal = VaultManager.UpgradeProposal({
            newImplementation: newImplementation,
            deadline: proposalDeadline
        });

        emit ISegMintVaultManager.UpgradeProposed({
            admin: msg.sender,
            implementation: newImplementation,
            deadline: proposalDeadline
        });
    }

    /**
     * @inheritdoc ISegMintVaultManager
     */
    function cancelUpgrade() external override onlyRoles(_ROLE_0) {
        /// Checks: Ensure there is a proposal to cancel.
        if (upgradeProposal.deadline == 0) revert Errors.NoProposalExists();

        address proposedImplementation = upgradeProposal.newImplementation;
        upgradeProposal = VaultManager.UpgradeProposal({ newImplementation: address(0), deadline: 0 });

        emit ISegMintVaultManager.UpgradeCancelled({ admin: msg.sender, implementation: proposedImplementation });
    }

    /**
     * @inheritdoc ISegMintVaultManager
     */
    function executeUpgrade(bytes memory payload) external override onlyRoles(_ROLE_0) {
        /// Checks: Ensure the proposed implementation is non-zero.
        if (upgradeProposal.newImplementation == address(0)) revert Errors.NoProposalExists();

        /// Checks: Ensure the time lock has expired.
        if (upgradeProposal.deadline > block.timestamp) revert Errors.UpgradeTimeLocked();

        address proposedImplementation = upgradeProposal.newImplementation;

        /// Effects: Clear the previous upgrade proposal and update the current version.
        upgradeProposal = VaultManager.UpgradeProposal({ newImplementation: address(0), deadline: 0 });

        // TODO: Revisit this and see what `payload` would be necessary.
        _upgradeToAndCallUUPS({ newImplementation: proposedImplementation, data: payload, forceCall: false });
    }

    /**
     * @inheritdoc ISegMintVaultManager
     */
    function setSignerModule(ISegMintSignerModule newSignerModule) external override onlyRoles(_ROLE_0) {
        ISegMintSignerModule oldSignerModule = signerModule;
        signerModule = newSignerModule;

        emit ISegMintVaultManager.SignerModuleUpdated({
            admin: msg.sender,
            oldSignerModule: oldSignerModule,
            newSignerModule: newSignerModule
        });
    }

    /**
     * @inheritdoc ISegMintVaultManager
     */
    function setKeys(ISegMintKeys newKeys) external override onlyRoles(_ROLE_0) {
        ISegMintKeys oldKeys = keys;
        keys = newKeys;

        emit ISegMintVaultManager.KeysUpdated({ admin: msg.sender, oldKeys: oldKeys, newKeys: newKeys });
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRoles(_ROLE_0) { }
}
