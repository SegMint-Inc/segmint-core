// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { OwnableRoles } from "solady/src/auth/OwnableRoles.sol";
import { ECDSA } from "solady/src/utils/ECDSA.sol";
import { LibClone } from "solady/src/utils/LibClone.sol";
import { EIP712 } from "solady/src/utils/EIP712.sol";
import { Initializable } from "@openzeppelin/proxy/utils/Initializable.sol";
import { IERC721 } from "@openzeppelin/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/token/ERC1155/IERC1155.sol";
import { UpgradeHandler } from "./UpgradeHandler.sol";
import { IServiceFactory } from "./interfaces/factories/IServiceFactory.sol";
import { ISegMintVault } from "./interfaces/ISegMintVault.sol";
import { ISegMintVaultSingle } from "./interfaces/ISegMintVaultSingle.sol";
import { ISegMintSafe } from "./interfaces/ISegMintSafe.sol";
import { ISegMintKYCRegistry } from "./interfaces/ISegMintKYCRegistry.sol";
import { ISegMintSignerModule } from "./interfaces/ISegMintSignerModule.sol";
import { ISegMintKeys } from "./interfaces/ISegMintKeys.sol";
import { Errors } from "./libraries/Errors.sol";
import { AssetType, KYCRegistry, Keys, Vault, Factory } from "./types/DataTypes.sol";

/**
 * @title ServiceFactory
 * @notice See documentation for {IServiceFactory}.
 */

contract ServiceFactory is IServiceFactory, OwnableRoles, UpgradeHandler, Initializable, EIP712 {
    using ECDSA for bytes32;
    using LibClone for address;

    /// keccak256("Asset(AssetType assetType,address token,uint256 identifier,uint256 amount)");
    bytes32 private constant _ASSET_TYPEHASH = 0x9ce23549803f44f7a1bf6b3815b78fcd9f18c5db5bcfe1cc57a3d568d1f8ab7d;

    /// @dev Maximum number of signers a SegMint Safe can have.
    uint256 private constant _MAX_SIGNERS = 20;

    /// @dev Vault/Safe creation fee.
    uint256 public creationFee = 0.002 ether;

    ISegMintSignerModule public signerModule;
    ISegMintKYCRegistry public kycRegistry;
    ISegMintKeys public keys;

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
     * @inheritdoc IServiceFactory
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

        emit IServiceFactory.VaultCreated({ user: msg.sender, vault: newVault });
    }

    /**
     * Function used to create a new single asset vault and fractionalize an asset via a signature.
     */
    /// forgefmt: disable-next-item
    function createVaultWithKeys(
        Vault.Asset calldata asset,
        uint256 keyAmount,
        bytes calldata signature
    ) external {
        /// Checks: Ensure the caller has registered with the KYC registry.
        KYCRegistry.AccessType accessType = kycRegistry.getAccessType(msg.sender);
        if (accessType == KYCRegistry.AccessType.BLOCKED) revert Errors.InvalidAccessType();

        /// Cache the current nonce value for the caller and post-increment.
        /// TODO: Might have to post-increment after to prevent re-entrancy.
        uint256 currentNonce = _vaultSingleNonce[msg.sender]++;

        /// Checks: Ensure the provided signature is valid.
        /// forgefmt: disable-next-item
        bytes32 digest = _hashTypedData(
            keccak256(
                abi.encode(
                    keccak256(abi.encode(
                        _ASSET_TYPEHASH,
                        asset.assetType,
                        asset.token,
                        asset.identifier,
                        asset.amount
                    )),
                    keyAmount,
                    currentNonce
                )
            )
        );

        address recoveredSigner = digest.toEthSignedMessageHash().recover(signature);
        if (signerModule.getSigner() != recoveredSigner) revert Errors.SignerMismatch();

        /// Checks: Ensure the asset type is compatible with single asset vaults.
        if (asset.assetType == AssetType.NONE || asset.assetType == AssetType.ERC20) revert Errors.InvalidAssetType();

        /// Checks: If the asset type is `ERC721`, the amount MUST be 1.
        if (asset.assetType == AssetType.ERC721 && asset.amount != 1) revert Errors.InvalidAssetAmount();
        
        /// Checks: As ERC1155 doesn't revert on zero amount transfers, ensure the amount is non-zero.
        if (asset.amount == 0) revert Errors.InvalidAssetAmount();

        /// Checks: Ensure the provided asset is not the keys contract.
        if (asset.token == address(keys)) revert Errors.CantLockKeys();

        /// Caclulate CREATE2 salt.
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, currentNonce));

        /// Sanity check to confirm the predicted address matches the actual addresses.
        /// This is done prior to any further storage updates. If this statement ever
        /// fails, chaos ensues.
        address predictedVault = vaultSingleImplementation.predictDeterministicAddress(salt, address(this));
        address newVault = vaultSingleImplementation.cloneDeterministic(salt);
        if (predictedVault != newVault) revert Errors.AddressMismatch();

        /// forgefmt: disable-next-item
        /// Transfer asset to the newly created clone.
        if (asset.assetType == AssetType.ERC721) {
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

        /// Approve the newly created vault with the keys contract to allow for
        /// further interactions with `keys` to be decoupled from this contract.
        uint256 keyId = keys.createKeys({
            amount: keyAmount,
            receiver: msg.sender,
            keyType: Vault.KeyType.SINGLE_ASSET
        });

        Keys.Bindings memory keyBindings = Keys.Bindings({ binded: true, keyId: keyId, amount: keyAmount });

        /// Initialize the newly created clone.
        ISegMintVaultSingle(newVault).initialize({ keys_: keys, asset_: asset, keyBindings_: keyBindings });
    }

    /**
     * Function used to create a new single asset vault and fractionalize an asset using
     * the chain's native token as payment.
     */
    /// forgefmt: disable-next-item
    function createVaultWithKeys(
        Vault.Asset calldata asset,
        uint256 keyAmount
    ) external payable {
        /// Checks: Ensure the caller has provided a sufficent value.
        // if (msg.value != vaultFee) revert Errors.InsufficientPayment();

        /// Checks: Ensure the caller has registered with the KYC registry.
        KYCRegistry.AccessType accessType = kycRegistry.getAccessType(msg.sender);
        if (accessType == KYCRegistry.AccessType.BLOCKED) revert Errors.InvalidAccessType();

        /// Cache the current nonce value for the caller and post-increment.
        /// TODO: Might have to post-increment after to prevent re-entrancy.
        uint256 currentNonce = _vaultSingleNonce[msg.sender]++;

        /// Checks: Ensure the asset type is compatible with single asset vaults.
        if (asset.assetType == AssetType.NONE || asset.assetType == AssetType.ERC20) revert Errors.InvalidAssetType();

        /// Checks: If the asset type is `ERC721`, the amount MUST be 1.
        if (asset.assetType == AssetType.ERC721 && asset.amount != 1) revert Errors.InvalidAssetAmount();
        
        /// Checks: As ERC1155 doesn't revert on zero amount transfers, ensure the amount is non-zero.
        if (asset.assetType == AssetType.ERC1155 && asset.amount == 0) revert Errors.InvalidAssetAmount();

        /// Checks: Ensure the provided asset is not the keys contract.
        if (asset.token == address(keys)) revert Errors.CantLockKeys();

        /// Caclulate CREATE2 salt.
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, currentNonce));

        /// Sanity check to confirm the predicted address matches the actual addresses.
        /// This is done prior to any further storage updates. If this statement ever
        /// fails, chaos ensues.
        address predictedVault = vaultSingleImplementation.predictDeterministicAddress(salt, address(this));
        address newVault = vaultSingleImplementation.cloneDeterministic(salt);
        if (predictedVault != newVault) revert Errors.AddressMismatch();

        /// forgefmt: disable-next-item
        /// Transfer asset to the newly created clone.
        if (asset.assetType == AssetType.ERC721) {
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

        /// Approve the newly created vault with the keys contract to allow for
        /// further interactions with `keys` to be decoupled from this contract.
        uint256 keyId = keys.createKeys({
            amount: keyAmount,
            receiver: msg.sender,
            keyType: Vault.KeyType.SINGLE_ASSET
        });

        Keys.Bindings memory keyBindings = Keys.Bindings({ binded: true, keyId: keyId, amount: keyAmount });

        /// Initialize the newly created clone.
        ISegMintVaultSingle(newVault).initialize({ keys_: keys, asset_: asset, keyBindings_: keyBindings });
    }

    /**
     * @inheritdoc IServiceFactory
     */
    function createSafe(bytes calldata signature, address[] calldata signers, uint256 quorum) external override {
        /// Checks: Ensure the provided signature is valid.
        bytes32 digest = keccak256(abi.encodePacked(msg.sender, "CREATE_SAFE"));
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

        emit IServiceFactory.SafeCreated({ user: msg.sender, safe: newSafe });
    }

    /**
     * @inheritdoc IServiceFactory
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
     * @inheritdoc IServiceFactory
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

    /**
     * Function used to withdraw the fees from vault creation.
     */
    function withdrawFees() external onlyOwner {
        (bool success,) = msg.sender.call{value: address(this).balance}("");
        if (!success) revert Errors.WithdrawFailed();
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     UPGRADE FUNCTIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @inheritdoc IServiceFactory
     */
    function proposeUpgrade(address newImplementation) external onlyRoles(_ROLE_0) {
        _proposeUpgrade(newImplementation);
    }

    /**
     * @inheritdoc IServiceFactory
     */
    function cancelUpgrade() external onlyRoles(_ROLE_0) {
        _cancelUpgrade();
    }

    /**
     * @inheritdoc IServiceFactory
     */
    function executeUpgrade(bytes memory payload) external onlyRoles(_ROLE_0) {
        _executeUpgrade(payload);
    }

    /**
     * Overriden to ensure that only callers with the `_ROLE_0` can upgrade the implementation.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRoles(_ROLE_0) { }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EIP712                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Overriden as required in Solady EIP712 documentation.
     */
    function _domainNameAndVersion() internal pure override returns (string memory name, string memory version) {
        name = "SegMint Factory";
        version = "1.0";
    }
}
