// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { OwnableRoles } from "solady/src/auth/OwnableRoles.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";
import { LibClone } from "solady/src/utils/LibClone.sol";
import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { IERC721 } from "@openzeppelin/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/token/ERC1155/IERC1155.sol";
import { UpgradeHandler } from "../handlers/UpgradeHandler.sol";
import { IVaultFactory } from "../interfaces/IVaultFactory.sol";
import { IMAVault } from "../interfaces/IMAVault.sol";
import { ISAVault } from "../interfaces/ISAVault.sol";
import { IKYCRegistry } from "../interfaces/IKYCRegistry.sol";
import { ISignerRegistry } from "../interfaces/ISignerRegistry.sol";
import { IKeys } from "../interfaces/IKeys.sol";
import { Asset, AssetClass, VaultType } from "../types/DataTypes.sol";

/**
 * @title VaultFactory
 * @notice See documentation for {IVaultFactory}.
 */

contract VaultFactory is IVaultFactory, OwnableRoles, Initializable, UpgradeHandler {
    using LibClone for address;
    using ECDSA for bytes32;

    /// `keccak256("ADMIN_ROLE");`
    uint256 public constant ADMIN_ROLE = 0xa49807205ce4d355092ef5a8a18f56e8913cf4a201fbe287825b095693c21775;

    ISignerRegistry public signerRegistry;
    IKYCRegistry public kycRegistry;
    IKeys public keys;

    address public maVault;
    address public saVault;

    /// TODO: Optimise this by using 1 mapping.
    mapping(address account => uint256 nonce) private _maVaultNonce;
    mapping(address account => uint256 nonce) private _saVaultNonce;

    /**
     * @inheritdoc IVaultFactory
     */
    function initialize(
        address admin_,
        address maVault_,
        address saVault_,
        ISignerRegistry signerRegistry_,
        IKYCRegistry kycRegistry_,
        IKeys keys_
    ) external initializer {
        _initializeOwner(msg.sender);
        _grantRoles(admin_, ADMIN_ROLE);

        maVault = maVault_;
        saVault = saVault_;

        signerRegistry = signerRegistry_;
        kycRegistry = kycRegistry_;
        keys = keys_;
    }

    /**
     * @inheritdoc IVaultFactory
     */
    function createMultiAssetVault(bytes calldata signature) external {
        /// Checks: Ensure the caller has valid access.
        IKYCRegistry.AccessType _accessType = kycRegistry.accessType(msg.sender);
        if (_accessType == IKYCRegistry.AccessType.BLOCKED) revert IKYCRegistry.InvalidAccessType();

        /// Cache current nonce and post-increment.
        uint256 maNonce = _maVaultNonce[msg.sender]++;

        bytes32 digest = keccak256(abi.encodePacked(msg.sender, block.chainid, maNonce, VaultType.MULTI));
        address recoveredSigner = digest.toEthSignedMessageHash().recover(signature);

        /// Checks: Ensure the provided signature is valid.
        if (signerRegistry.getSigner() != recoveredSigner) revert ISignerRegistry.SignerMismatch();

        /// Caclulate CREATE2 salt.
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, maNonce));

        /// Create a clone of the `maVault` implementation.
        address newVault = maVault.cloneDeterministic(salt);

        /// Initialize the newly created clone.
        IMAVault(newVault).initialize({ owner_: msg.sender, keys_: keys });

        /// Approve the newly created vault with the keys contract to allow for
        /// further interactions with `keys` to be decoupled from this contract.
        keys.registerVault(newVault);

        emit IVaultFactory.VaultCreated({ user: msg.sender, vault: newVault, vaultType: VaultType.MULTI });
    }

    /**
     * @inheritdoc IVaultFactory
     */
    function createSingleAssetVault(Asset calldata asset, uint256 keyAmount, bytes calldata signature) external {
        /// Checks: Ensure the caller has valid access.
        IKYCRegistry.AccessType _accessType = kycRegistry.accessType(msg.sender);
        if (_accessType == IKYCRegistry.AccessType.BLOCKED) revert IKYCRegistry.InvalidAccessType();

        /// Cache the current nonce value for the caller and post-increment.
        uint256 saNonce = _saVaultNonce[msg.sender]++;

        bytes32 digest = keccak256(abi.encodePacked(msg.sender, block.chainid, saNonce, VaultType.SINGLE));
        address recoveredSigner = digest.toEthSignedMessageHash().recover(signature);

        /// Checks: Ensure the recovered signer matches the registered signer.
        if (signerRegistry.getSigner() != recoveredSigner) revert ISignerRegistry.SignerMismatch();

        /// Caclulate CREATE2 salt.
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, saNonce));

        /// Create a clone of the `saVault` implementation.
        address newVault = saVault.cloneDeterministic(salt);

        /// Approve the newly created vault with the keys contract to allow for
        /// further interactions with `keys` to be decoupled from this contract.
        keys.registerVault(newVault);

        /// Initialize the newly created clone.
        ISAVault(newVault).initialize({ _asset: asset, _keys: keys, _keyAmount: keyAmount, _receiver: msg.sender });

        /// forgefmt: disable-next-item
        /// Transfer asset to the newly created clone after initialization.
        if (asset.class == AssetClass.ERC721) {
            IERC721(asset.token).safeTransferFrom({
                from: msg.sender,
                to: newVault,
                tokenId: asset.identifier
            });
        } else {
            IERC1155(asset.token).safeTransferFrom({
                from: msg.sender,
                to: newVault,
                id: asset.identifier,
                value: asset.amount,
                data: ""
            });
        }

        /// Emit vault creation event.
        emit IVaultFactory.VaultCreated({ user: msg.sender, vault: newVault, vaultType: VaultType.SINGLE });
    }

    /**
     * @inheritdoc IVaultFactory
     */
    function getMultiAssetVaults(address account) external view returns (address[] memory) {
        uint256 mavNonce = _maVaultNonce[account];
        return _predictDeployments(account, mavNonce, maVault);
    }

    /**
     * @inheritdoc IVaultFactory
     */
    function getSingleAssetVaults(address account) external view returns (address[] memory) {
        uint256 savNonce = _saVaultNonce[account];
        return _predictDeployments(account, savNonce, saVault);
    }

    /**
     * @inheritdoc IVaultFactory
     */
    function getNonces(address account) external view returns (uint256 maNonce, uint256 saNonce) {
        maNonce = _maVaultNonce[account];
        saNonce = _saVaultNonce[account];
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     UPGRADE FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @inheritdoc IVaultFactory
     */
    function proposeUpgrade(address newImplementation) external onlyRoles(ADMIN_ROLE) {
        _proposeUpgrade(newImplementation);
    }

    /**
     * @inheritdoc IVaultFactory
     */
    function cancelUpgrade() external onlyRoles(ADMIN_ROLE) {
        _cancelUpgrade();
    }

    /**
     * @inheritdoc IVaultFactory
     */
    function executeUpgrade(bytes memory payload) external onlyRoles(ADMIN_ROLE) {
        _executeUpgrade(payload);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      VERSION CONTROL                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @inheritdoc IVaultFactory
     */
    function nameAndVersion() external pure virtual returns (string memory name, string memory version) {
        name = "Vault Factory";
        version = "1.0";
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       INTERNAL LOGIC                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function _predictDeployments(address account, uint256 nonce, address implementation)
        private
        view
        returns (address[] memory)
    {
        address[] memory deployments = new address[](nonce);

        for (uint256 i = 0; i < nonce; i++) {
            bytes32 salt = keccak256(abi.encodePacked(account, i));
            deployments[i] = implementation.predictDeterministicAddress(salt, address(this));
        }

        return deployments;
    }

    /**
     * Overriden to ensure that only callers with the correct role can perform an upgrade.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRoles(ADMIN_ROLE) { }
}
