// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { OwnableRoles } from "solady/src/auth/OwnableRoles.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";
import { LibClone } from "solady/src/utils/LibClone.sol";
import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/proxy/utils/UUPSUpgradeable.sol";
import { IERC721 } from "@openzeppelin/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/token/ERC1155/IERC1155.sol";
import { ISegMintVaultManager } from "./interfaces/ISegMintVaultManager.sol";
import { ISegMintVault } from "./interfaces/ISegMintVault.sol";
import { ISegMintVaultSingle } from "./interfaces/ISegMintVaultSingle.sol";
import { ISegMintSafe } from "./interfaces/ISegMintSafe.sol";
import { ISegMintKYCRegistry } from "./interfaces/ISegMintKYCRegistry.sol";
import { ISegMintSignerModule } from "./interfaces/ISegMintSignerModule.sol";
import { ISegMintKeys } from "./interfaces/ISegMintKeys.sol";
import { Errors } from "./libraries/Errors.sol";
import { KYCRegistry, Vault, VaultSingle, VaultManager } from "./types/DataTypes.sol";

/**
 * @title SegMintVaultManager
 * @notice See documentation for {ISegMintVaultManager}.
 */

contract SegMintVaultManager is ISegMintVaultManager, OwnableRoles, Initializable, UUPSUpgradeable {
    using ECDSA for bytes32;
    using LibClone for address;

    /// @dev Implementation upgrade proposals cannot be executed for 5 days.
    uint256 private constant _UPGRADE_TIMELOCK = 5 days;

    /// @dev Maximum number of signers a SegMint Safe can have.
    uint256 private constant _MAX_SIGNERS = 20;

    ISegMintSignerModule public signerModule;
    ISegMintKYCRegistry public kycRegistry;
    ISegMintKeys public keys;

    VaultManager.UpgradeProposal public upgradeProposal;

    address public vaultImplementation;
    address public vaultSingleImplementation;
    address public safeImplementation;

    mapping(address account => uint256 nonce) private _vaultNonce;
    mapping(address account => uint256 nonce) private _vaultSingleNonce;
    mapping(address account => uint256 nonce) private _safeNonce;

    function initialize(
        address admin_,
        address vaultImplementation_,
        address vaultSingleImplementation_,
        address safeImplementation_,
        ISegMintSignerModule signerModule_,
        ISegMintKYCRegistry kycRegistry_,
        ISegMintKeys keys_
    ) external override initializer {
        _initializeOwner(msg.sender);
        _grantRoles(admin_, _ROLE_0);

        vaultImplementation = vaultImplementation_;
        vaultSingleImplementation = vaultSingleImplementation_;
        safeImplementation = safeImplementation_;

        signerModule = signerModule_;
        kycRegistry = kycRegistry_;
        keys = keys_;
    }

    /**
     * @inheritdoc ISegMintVaultManager
     * @dev `msg.sender` will be the EOA that invoked the function call.
     */
    function createVault(bytes calldata signature) external override {
        /// Checks: Ensure the caller has access.
        KYCRegistry.AccessType accessType = kycRegistry.getAccessType(msg.sender);
        if (accessType == KYCRegistry.AccessType.BLOCKED) revert Errors.InvalidAccessType();

        /// Checks: Ensure the provided signature is valid.
        bytes32 digest = keccak256(abi.encodePacked(msg.sender, accessType, "CREATE_VAULT"));
        address recoveredSigner = digest.toEthSignedMessageHash().recover(signature);
        if (signerModule.getSigner() != recoveredSigner) revert Errors.SignerMismatch();

        /// Cache current nonce and increment.
        uint256 currentNonce = _vaultNonce[msg.sender]++;

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
        keys.approveVault(newVault);

        emit ISegMintVaultManager.VaultCreated({ user: msg.sender, vault: newVault });
    }

    function createVaultSingle(bytes calldata signature, VaultSingle.Asset calldata asset) external {
        /// Checks: Ensure the caller has access.
        KYCRegistry.AccessType accessType = kycRegistry.getAccessType(msg.sender);
        if (accessType == KYCRegistry.AccessType.BLOCKED) revert Errors.InvalidAccessType();

        /// Checks: Ensure the provided asset is of a valid type.
        if (asset.class == VaultSingle.SingleClass.NONE) revert Errors.InvalidAssetClass();

        /// Checks: Ensure the user is not trying to lock keys.
        if (asset.addr == address(keys)) revert Errors.CantLockKeys();

        /// Checks: Ensure the provided signature is valid.
        bytes32 digest = keccak256(abi.encodePacked(msg.sender, accessType, "CREATE_VAULT_SINGLE"));
        address recoveredSigner = digest.toEthSignedMessageHash().recover(signature);
        if (signerModule.getSigner() != recoveredSigner) revert Errors.SignerMismatch();

        /// Cache current nonce and increment.
        uint256 currentNonce = _vaultSingleNonce[msg.sender]++;

        /// Caclulate CREATE2 salt.
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, currentNonce));

        /// Sanity check to confirm the predicted address matches the actual addresses.
        /// This is done prior to any further storage updates. If this statement ever
        /// fails, chaos ensues.
        address predictedVault = vaultSingleImplementation.predictDeterministicAddress(salt, address(this));
        address newVault = vaultSingleImplementation.cloneDeterministic(salt);
        if (predictedVault != newVault) revert Errors.AddressMismatch();

        /// Transfer asset to the newly created clone.
        if (asset.class == VaultSingle.SingleClass.ERC_721) {
            IERC721(asset.addr).safeTransferFrom({ from: msg.sender, to: newVault, tokenId: asset.tokenId });
        } else {
            IERC1155(asset.addr).safeTransferFrom({
                from: msg.sender,
                to: newVault,
                id: asset.tokenId,
                amount: asset.amount,
                data: ""
            });
        }

        /// Initialize the newly created clone.
        ISegMintVaultSingle(newVault).initialize(msg.sender, keys, asset);

        /// Approve the newly created vault with the keys contract to allow for
        /// further interactions with `keys` to be decoupled from this contract.
        keys.approveVault(newVault);
    }

    /**
     * @inheritdoc ISegMintVaultManager
     */
    function createSafe(bytes calldata signature, address[] calldata signers, uint256 quorum) external override {
        /// Checks: Ensure the caller has access.
        KYCRegistry.AccessType accessType = kycRegistry.getAccessType(msg.sender);
        if (accessType == KYCRegistry.AccessType.BLOCKED) revert Errors.InvalidAccessType();

        /// Checks: Ensure the provided signature is valid.
        bytes32 digest = keccak256(abi.encodePacked(msg.sender, accessType, "CREATE_SAFE"));
        address recoveredSigner = digest.toEthSignedMessageHash().recover(signature);
        if (signerModule.getSigner() != recoveredSigner) revert Errors.SignerMismatch();

        /// Checks: Ensure a valid number of signers has been provided.
        if (signers.length == 0) revert Errors.ZeroLengthArray();
        if (signers.length > _MAX_SIGNERS) revert Errors.OverMaxSigners();

        /// Checks: Ensure that a valid quorum value has been provided.
        if (quorum == 0 || quorum > signers.length) revert Errors.InvalidQuorumValue();

        /// Cache current nonce and increment.
        uint256 currentNonce = _safeNonce[msg.sender]++;

        /// Caclulate CREATE2 salt.
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, currentNonce));

        /// Sanity check to confirm the predicted address matches the actual addresses.
        /// This is done prior to any further storage updates. If this statement ever
        /// fails, chaos ensues.
        address predictedSafe = safeImplementation.predictDeterministicAddress(salt, address(this));
        address newSafe = safeImplementation.cloneDeterministic(salt);
        if (predictedSafe != newSafe) revert Errors.AddressMismatch();

        /// Initialize the newly created clone.
        ISegMintSafe(newSafe).initialize(signers, quorum);

        emit ISegMintVaultManager.SafeCreated({ user: msg.sender, safe: newSafe });
    }

    /**
     * @inheritdoc ISegMintVaultManager
     */
    function getVaults(address account) external view override returns (address[] memory) {
        uint256 length = _vaultNonce[account];
        address[] memory vaults = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            bytes32 salt = keccak256(abi.encodePacked(account, i));
            vaults[i] = vaultImplementation.predictDeterministicAddress(salt, address(this));
        }

        return vaults;
    }

    function getSingleVaults(address account) external view returns (address[] memory) {
        uint256 length = _vaultSingleNonce[account];
        address[] memory vaults = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            bytes32 salt = keccak256(abi.encodePacked(account, i));
            vaults[i] = vaultSingleImplementation.predictDeterministicAddress(salt, address(this));
        }

        return vaults;
    }

    /**
     * @inheritdoc ISegMintVaultManager
     */
    function getSafes(address account) external view override returns (address[] memory) {
        uint256 length = _safeNonce[account];
        address[] memory safes = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            bytes32 salt = keccak256(abi.encodePacked(account, i));
            safes[i] = safeImplementation.predictDeterministicAddress(salt, address(this));
        }

        return safes;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     UPGRADE FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

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

        /// Clear the previous upgrade proposal and update the current version.
        upgradeProposal = VaultManager.UpgradeProposal({ newImplementation: address(0), deadline: 0 });

        /// Upgrade to the proposed implementation.
        _upgradeToAndCallUUPS({ newImplementation: proposedImplementation, data: payload, forceCall: false });
    }

    /**
     * @dev Overriden to ensure that only callers with the `_ROLE_0` can upgrade the implementation.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRoles(_ROLE_0) { }
}
