// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { OwnableRoles } from "solady/src/auth/OwnableRoles.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";
import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/proxy/utils/UUPSUpgradeable.sol";
import { SegMintVault } from "./SegMintVault.sol";
import { ISegMintVaultManager } from "./interfaces/ISegMintVaultManager.sol";
import { ISegMintVault } from "./interfaces/ISegMintVault.sol";
import { ISegMintKYCRegistry } from "./interfaces/ISegMintKYCRegistry.sol";
import { Errors } from "./libraries/Errors.sol";
import { KYCRegistry, Vault, VaultManager } from "./types/DataTypes.sol";

contract SegMintVaultManager is ISegMintVaultManager, OwnableRoles, Initializable, UUPSUpgradeable {
    using ECDSA for bytes32;

    /// @dev Upgrade proposals cannot be executed for 5 days.
    uint256 private constant _UPGRADE_TIMELOCK = 5 days;

    ISegMintKYCRegistry public kycRegistry;
    VaultManager.UpgradeProposal public upgradeProposal;
    address public signer;

    mapping(address account => SegMintVault[] vaults) private _vaults;

    function initialize(address admin_, address signer_, ISegMintKYCRegistry kycRegistry_) external initializer {
        _initializeOwner(msg.sender);
        _grantRoles(admin_, _ROLE_0);

        signer = signer_;
        kycRegistry = kycRegistry_;
    }

    /**
     * @inheritdoc ISegMintVaultManager
     */
    function createVault(bytes calldata signature) external override {
        /// Checks: Ensure the caller has a valid access.
        KYCRegistry.AccessType accessType = kycRegistry.getAccessType(msg.sender);
        if (accessType == KYCRegistry.AccessType.BLOCKED) revert Errors.InvalidAccessType();

        /// Checks: Ensure the provided signature is valid.
        bytes32 digest = keccak256(abi.encodePacked(msg.sender, accessType, "CREATE_VAULT"));
        address recoveredSigner = digest.toEthSignedMessageHash().recover(signature);
        if (signer != recoveredSigner) revert Errors.SignerMismatch();

        SegMintVault newVault = new SegMintVault(msg.sender);
        _vaults[msg.sender].push(newVault);

        emit VaultCreated({ user: msg.sender, vault: newVault });
    }

    /**
     * @inheritdoc ISegMintVaultManager
     */
    function getVaults(address account) external view override returns (SegMintVault[] memory) {
        uint256 length = _vaults[account].length;
        SegMintVault[] memory vaults = new SegMintVault[](length);

        for (uint256 i = 0; i < length; i++) {
            vaults[i] = _vaults[account][i];
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

        // TODO: Revisit this and refine data parameter.
        _upgradeToAndCallUUPS({ newImplementation: proposedImplementation, data: payload, forceCall: false });
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRoles(_ROLE_0) { }
}
