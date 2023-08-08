// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { OwnableRoles } from "solady/src/auth/OwnableRoles.sol";
import { ERC1155 } from "@openzeppelin/token/ERC1155/ERC1155.sol";
import { ISegMintKeys } from "./interfaces/ISegMintKeys.sol";
import { ISegMintKYCRegistry } from "./interfaces/ISegMintKYCRegistry.sol";
import { KYCRegistry } from "./types/DataTypes.sol";
import { Errors } from "./libraries/Errors.sol";

contract SegMintKeys is ISegMintKeys, OwnableRoles, ERC1155 {
    ISegMintKYCRegistry public kycRegistry;
    // ISegMintKeyExchange public keyExchange;

    modifier isApprovedVault() {
        /// Checks: Ensure the caller is an approved vault.
        if (!isApproved[msg.sender]) revert Errors.VaultNotApproved();
        _;
    }

    /// @dev Total number of unique keys in circulation.
    uint64 private uniqueKeys;

    mapping(address vault => bool approved) public isApproved;
    mapping(uint256 keyId => bool frozen) public isFrozen;

    constructor(address admin_, string memory uri_, ISegMintKYCRegistry kycRegistry_) ERC1155(uri_) {
        _initializeOwner(msg.sender);
        _grantRoles(admin_, _ROLE_0);
        kycRegistry = kycRegistry_;
    }

    function burnKeys(address holder, uint256 keyId, uint256 amount) external isApprovedVault {
        /// Checks: Ensure that frozen keys cannot be destroyed.
        if (isFrozen[keyId]) revert Errors.KeysFrozen();

        _burn({ from: holder, id: keyId, amount: amount });
    }

    function createKeys(uint256 amount, address receiver) external isApprovedVault returns (uint256) {
        /// Cache current key ID and increment.
        uint256 keyId = ++uniqueKeys;

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

    function setURI(string calldata newURI) external onlyRoles(_ROLE_0) {
        _setURI(newURI);
    }

    /**
     * Overriden to ensure that `to` has a valid access type.
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data)
        public
        override
    {
        /// Checks: Ensure that `id` is not frozen.
        if (isFrozen[id]) revert Errors.KeysFrozen();

        /// Checks: Ensure that `receiver` has a valid access type.
        KYCRegistry.AccessType accessType = kycRegistry.getAccessType(to);
        if (accessType == KYCRegistry.AccessType.BLOCKED) revert Errors.InvalidAccessType();

        _safeTransferFrom(from, to, id, amount, data);
    }

    function freezeKeys(uint256 keyId) external onlyRoles(_ROLE_0) {
        isFrozen[keyId] = true;

        emit ISegMintKeys.KeyFrozen({ admin: msg.sender, keyId: keyId });
    }

    function unfreezeKeys(uint256 keyId) external onlyRoles(_ROLE_0) {
        isFrozen[keyId] = false;

        emit ISegMintKeys.KeyUnfrozen({ admin: msg.sender, keyId: keyId });
    }

    /**
     * Overriden to allow key claw back functionality.
     */
    // function isApprovedForAll(address account, address operator) public view override returns (bool) {
    //     if (operator == address(SegMintKeyExchange)) {
    //         return true;
    //     } else {
    //         return super.isApprovedForAll(account, operator);
    //     }
    // }
}
