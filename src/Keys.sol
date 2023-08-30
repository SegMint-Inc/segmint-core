// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { OwnableRoles } from "solady/src/auth/OwnableRoles.sol";
import { ERC1155 } from "@openzeppelin/token/ERC1155/ERC1155.sol";
import { IKeys } from "./interfaces/IKeys.sol";
import { IKYCRegistry } from "./interfaces/IKYCRegistry.sol";
import { VaultType, KeyBinds } from "./types/DataTypes.sol";

/**
 * @title Keys
 * @notice See documentation for {IKeys}.
 */

contract Keys is IKeys, OwnableRoles, ERC1155 {
    /// @dev keccak256("_ADMIN_ROLE")
    uint256 private constant _ADMIN_ROLE = 0x4a4566510e9351b52a3e4f6550fc68d8577350bec07d7a69da4906b0efe533bc;

    /// @dev keccak256("FACTORY_ROLE")
    uint256 private constant _FACTORY_ROLE = 0xee961466e472802bc53e28ea01e7875c1285a5d1f1992f7b1aafc450304db8bc;

    /// Minimum duration of a lend.
    uint256 private constant _MIN_LEND_DURATION = 1 days;

    /// Maximum duration of a lend.
    uint256 private constant _MAX_LEND_DURATION = 365 days;

    /// Maximum number of keys that can be created for a single identifier.
    uint256 private constant _MAX_KEYS = 100;

    /// Denotes the concept of a key creator, or rather the account that initially minted the keys.
    mapping(uint256 keyId => address account) private _creators;

    mapping(address vault => KeyBinds bindings) private _keyBinds;

    /// Interface for KYC registry.
    IKYCRegistry public kycRegistry;

    address public keyExchange;

    /// Counts the number of unique keys created.
    uint256 public keysCreated;

    /// Mapping of active lends.
    mapping(address lendee => mapping(uint256 keyId => LendingTerms lendingTerm)) public activeLends;
    mapping(address vault => bool registered) public isRegistered;
    mapping(uint256 keyId => bool frozen) public isFrozen;

    /// forgefmt: disable-next-item
    constructor(
        address admin_,
        string memory uri_,
        IKYCRegistry kycRegistry_
    ) ERC1155(uri_) {
        _initializeOwner(msg.sender);
        _grantRoles(admin_, _ADMIN_ROLE);

        kycRegistry = kycRegistry_;
    }

    /**
     * @inheritdoc IKeys
     */
    /// TODO: Unregister a vault after keys have been created.
    function createKeys(uint256 amount, address receiver) external returns (uint256) {
        /// Checks: Ensure a valid amount of keys are being created.
        if (amount == 0 || amount > _MAX_KEYS) revert InvalidKeyAmount();

        /// Checks: Ensure the caller is a registered vault or has the factory role.
        if (!isRegistered[msg.sender]) revert CallerNotRegistered();

        /// Increment the number of keys created and push this value to the stack. The pre-increment
        /// is done to ensure that keys with an ID of 0 are never created.
        uint256 keyId = ++keysCreated;

        /// Acknowledge the `receiver` as the creator of this particular key ID.
        _creators[keyId] = receiver;

        /// Update the key bindings associated with the vault.
        // keyBinds[msg.sender] = KeyBinds({ vaultType: vaultType, isFrozen: false, keyId: keyId, amount: amount });

        /// Mint keys to `receiver`.
        _mint({ to: receiver, id: keyId, value: amount, data: "" });

        return keyId;
    }

    /**
     * @inheritdoc IKeys
     */
    function burnKeys(address holder, uint256 keyId, uint256 amount) external {
        /// Checks: Ensure that frozen keys cannot be destroyed.
        if (isFrozen[keyId]) revert KeysFrozen();

        /// Checks: Ensure the caller is a registered vault.
        if (!isRegistered[msg.sender]) revert CallerNotRegistered();

        /// The `amount` does not require sanitization as the vault itself will keep track of
        /// how many keys are associated with it.
        _burn({ from: holder, id: keyId, value: amount });
    }

    /**
     * @inheritdoc IKeys
     */
    function lendKeys(address lendee, uint256 keyId, uint256 lendAmount, uint256 lendDuration) external {
        /// Checks: Ensure the key idenitifier is not frozen.
        if (isFrozen[keyId]) revert KeysFrozen();

        /// Checks: Ensure the lendee has valid access.
        IKYCRegistry.AccessType accessType = kycRegistry.accessType(lendee);
        if (accessType == IKYCRegistry.AccessType.BLOCKED) revert IKYCRegistry.InvalidAccessType();

        /// Checks: Ensure the lendee does not already have an active lend for `keyId`.
        if (activeLends[lendee][keyId].lender != address(0)) revert HasActiveLend();

        /// Checks: Ensure that a valid amount of keys are being lended.
        if (lendAmount == 0 || lendAmount > _MAX_KEYS) revert InvalidKeyAmount();

        /// Checks: Ensure a valid lend duration has been provided.
        if (lendDuration < _MIN_LEND_DURATION || lendDuration > _MAX_LEND_DURATION) revert InvalidLendDuration();

        uint40 lendExpiryTime = uint40(block.timestamp + lendDuration);

        /// Define the lending terms.
        /// forgefmt: disable-next-item
        activeLends[lendee][keyId] = LendingTerms({
            lender: msg.sender,
            amount: uint56(lendAmount),
            expiryTime: lendExpiryTime
        });

        /// `keyId` and `lendAmount` do not need to be sanitized as `safeTransferFrom` will fail
        /// if either `keyId` does not exist of `lendAmount` exceeds the lenders balance. We use
        /// `_safeTransferFrom` here to circumvent the `isApprovedForAll` check.
        _safeTransferFrom({ from: msg.sender, to: lendee, id: keyId, value: lendAmount, data: "" });
    }

    /**
     * @inheritdoc IKeys
     */
    // TODO: Check if reclaim should only be callable after a lend has expired.
    function reclaimKeys(address lendee, uint256 keyId) external {
        /// Checks: Ensure the key idenitifier is not frozen.
        if (isFrozen[keyId]) revert KeysFrozen();

        /// Cache lending terms in memory.
        LendingTerms memory lendingTerms = activeLends[lendee][keyId];

        /// Checks: Ensure lendee has an active lend.
        if (lendingTerms.expiryTime == 0) revert NoActiveLend();

        /// Checks: Ensure that the lending period has elapsed.
        if (lendingTerms.expiryTime > block.timestamp) revert LendStillActive();

        /// Clear lending terms.
        activeLends[lendee][keyId] = LendingTerms({ lender: address(0), amount: 0, expiryTime: 0 });

        /// `keyId` does not need to be sanitized as `_safeTransferFrom` will fail if `keyId` does not exist.
        /// We use `_safeTransferFrom` here to circumvent the `isApprovedForAll` check but retain the zero address
        /// checks to prevent an alternative method of burning keys.
        _safeTransferFrom({ from: lendee, to: lendingTerms.lender, id: keyId, value: lendingTerms.amount, data: "" });
    }

    /**
     * @inheritdoc IKeys
     */
    function registerVault(address vault) external onlyRoles(_FACTORY_ROLE) {
        isRegistered[vault] = true;
    }

    /**
     * @inheritdoc IKeys
     */
    function freezeKeys(uint256 keyId) external onlyRoles(_ADMIN_ROLE) {
        isFrozen[keyId] = true;

        emit IKeys.KeyFrozen({ admin: msg.sender, keyId: keyId });
    }

    /**
     * @inheritdoc IKeys
     */
    function unfreezeKeys(uint256 keyId) external onlyRoles(_ADMIN_ROLE) {
        isFrozen[keyId] = false;

        emit IKeys.KeyUnfrozen({ admin: msg.sender, keyId: keyId });
    }

    /**
     * Function used to set the key exchange address.
     */
    function setKeyExchange(address _keyExchange) external onlyRoles(_ADMIN_ROLE) {
        keyExchange = _keyExchange;
    }

    /**
     * Overriden to ensure that `to` has a valid access type.
     */
    /// forgefmt: disable-next-item
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) public override {
        /// Checks: Ensure the caller is either the owner of the token or is an approved operator.
        address sender = _msgSender();
        if (from != sender && !isApprovedForAll(from, sender)) revert ERC1155MissingApprovalForAll(sender, from);

        /// Checks: Ensure the key idenitifier is not frozen.
        if (isFrozen[id]) revert KeysFrozen();

        /// Checks: Ensure that `to` has a valid access type.
        IKYCRegistry.AccessType accessType = kycRegistry.accessType(to);
        if (accessType == IKYCRegistry.AccessType.BLOCKED) revert IKYCRegistry.InvalidAccessType();

        /// Checks: Ensure zero value transfers are not allowed.
        if (value == 0) revert ZeroKeyTransfer();

        /// Check the lending status of the key.
        LendingTerms memory lendingTerms = activeLends[from][id];

        /// If `from` has no activeLends associated with `id`.
        if (lendingTerms.expiryTime == 0) {
            _safeTransferFrom(from, to, id, value, data);

            /// If some amount of keys are being transferred to the lender. We don't need to check
            /// the value here as we can guarantee that it is non-zero and a transfer of any non-zero
            /// amount of keys should clear the lending terms.
        } else if (to == lendingTerms.lender) {
            /// TODO: Ensure that returning 1 key doesn't fully clear the lending terms.

            /// Clear lending terms.
            activeLends[from][value] = LendingTerms({ lender: address(0), amount: 0, expiryTime: 0 });

            _safeTransferFrom(from, to, id, value, data);

            /// If a transfer is being attempted with a lend active to a non-lender.
        } else {
            /// Get the number of keys held by `from`.
            uint256 keysHeld = this.balanceOf({ account: from, id: id });

            /// Calculate the number of 'free' keys. A free key in this context is a key
            /// that is not owned on lend. Since lended keys are soulbound, we can expect
            /// `from` to be in posessesion of at least ONE key. Due to this, the operation
            /// `keysHeld - 1` should never revert.
            uint256 freeKeys = keysHeld - 1;

            // if (freeKeys == 0) revert SoulboundKey();

            /// If `from` has an insufficient free keys value.
            if (value > freeKeys) revert OverFreeKeyBalance();

            _safeTransferFrom(from, to, id, value, data);
        }
    }

    /**
     * @inheritdoc IKeys
     */
    function creatorOf(uint256 keyId) external view returns (address) {
        return _creators[keyId];
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     * This function has been overridden to ensure that the key exchange can perform buy outs.
     */
    function isApprovedForAll(address account, address operator) public view override returns (bool) {
        return operator == keyExchange ? true : super.isApprovedForAll(account, operator);
    }

    // TODO: Override `safeBatchTransferFrom` logic.

    /**
     * Function used to set a new URI associated with key metadata.
     */
    function setURI(string calldata newURI) external onlyRoles(_ADMIN_ROLE) {
        _setURI(newURI);
    }
}
