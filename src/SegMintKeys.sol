// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { OwnableRoles } from "solady/src/auth/OwnableRoles.sol";
import { ERC1155 } from "@openzeppelin/token/ERC1155/ERC1155.sol";
import { ISegMintKeys } from "./interfaces/ISegMintKeys.sol";
import { ISegMintKYCRegistry } from "./interfaces/ISegMintKYCRegistry.sol";
import { ISegMintVaultManager } from "./interfaces/ISegMintVaultManager.sol";
import { Errors } from "./libraries/Errors.sol";

contract SegMintKeys is ISegMintKeys, OwnableRoles, ERC1155 {
    ISegMintKYCRegistry public kycRegistry;
    ISegMintVaultManager public vaultManager;

    modifier isApprovedVault() {
        /// Checks: Ensure the caller is an approved vault.
        if (!isApproved[msg.sender]) revert Errors.VaultNotApproved();
        _;
    }

    /// @dev Tracks the total number of keys created.
    uint64 totalKeys;

    mapping(address vault => bool approved) public isApproved;

    constructor(address admin_, string memory uri_, ISegMintKYCRegistry kycRegistry_) ERC1155(uri_) {
        _initializeOwner(msg.sender);
        _grantRoles(admin_, _ROLE_0);
        kycRegistry = kycRegistry_;
    }

    function setVaultManager(ISegMintVaultManager newVaultManager) external onlyRoles(_ROLE_0) {
        ISegMintVaultManager oldVaultManager = vaultManager;
        vaultManager = newVaultManager;

        emit VaultManagerUpdated({
            admin: msg.sender,
            oldVaultManager: oldVaultManager,
            newVaultManager: newVaultManager
        });
    }

    function burnKeys(address holder, uint256 keyId, uint256 amount) external isApprovedVault {
        _burn({ from: holder, id: keyId, amount: amount });
    }

    function createKeys(uint256 amount, address receiver) external isApprovedVault returns (uint256) {
        /// Cache current key ID and increment.
        uint256 keyId = totalKeys++;

        /// Mint `amount` of keys to `receiver`.
        _mint({ to: receiver, id: keyId, amount: amount, data: "" });

        return keyId;
    }

    /**
     * @dev Vault creation ensures approval, so maybe `VaultApproved` event
     * is not needed?
     */
    function approveVault(address vault) external onlyRoles(_ROLE_1) {
        isApproved[vault] = true;
        emit ISegMintKeys.VaultApproved({ vault: vault });
    }
}
