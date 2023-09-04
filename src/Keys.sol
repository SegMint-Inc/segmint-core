// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { OwnableRoles } from "solady/src/auth/OwnableRoles.sol";
import { ERC1155 } from "@openzeppelin/token/ERC1155/ERC1155.sol";
import { IKeys } from "./interfaces/IKeys.sol";
import { IKYCRegistry } from "./interfaces/IKYCRegistry.sol";
import { VaultType, KeyConfig } from "./types/DataTypes.sol";

/**
 * @title Keys
 * @notice See documentation for {IKeys}.
 */

contract Keys is IKeys, OwnableRoles, ERC1155 {
    /// `keccak256("ADMIN_ROLE");`
    uint256 public constant ADMIN_ROLE = 0xa49807205ce4d355092ef5a8a18f56e8913cf4a201fbe287825b095693c21775;

    /// `keccak256("FACTORY_ROLE");`
    uint256 public constant FACTORY_ROLE = 0xdfbefbf47cfe66b701d8cfdbce1de81c821590819cb07e71cb01b6602fb0ee27;

    /// Minimum duration of a lend.
    uint256 public constant MIN_LEND_DURATION = 1 days;

    /// Maximum duration of a lend.
    uint256 public constant MAX_LEND_DURATION = 365 days;

    /// Maximum number of keys that can be created for a single identifier.
    uint256 public constant MAX_KEYS = 100;

    /// Maps a key ID to an associated configuration.
    mapping(uint256 keyId => KeyConfig config) private _keyConfig;

    /// Interface for KYC registry.
    IKYCRegistry public kycRegistry;

    /// Address of the key exchange.
    address public keyExchange;

    /// Counts the number of unique keys created.
    uint256 public keysCreated;

    /// Mapping of active lends.
    mapping(address lendee => mapping(uint256 keyId => LendingTerms lendingTerm)) private _activeLends;
    mapping(address vault => bool registered) public isRegistered;

    /// forgefmt: disable-next-item
    constructor(
        address admin_,
        string memory uri_,
        IKYCRegistry kycRegistry_
    ) ERC1155(uri_) {
        _initializeOwner(msg.sender);
        _grantRoles(admin_, ADMIN_ROLE);

        kycRegistry = kycRegistry_;
    }

    function createKeys(uint256 amount, address receiver, VaultType vaultType) external returns (uint256) {
        /// Checks: Ensure the caller is a registered vault or has the factory role.
        if (!isRegistered[msg.sender]) revert CallerNotRegistered();
        
        /// Checks: Ensure a valid amount of keys are being created.
        if (amount == 0 || amount > MAX_KEYS) revert InvalidKeyAmount();

        /// Increment the number of keys created and push this value to the stack. The pre-increment
        /// is done to ensure that keys with an ID of 0 are never created.
        uint256 keyId = ++keysCreated;

        /// Update the key bindings associated with the vault.
        _keyConfig[keyId] = KeyConfig({
            creator: receiver,
            vaultType: vaultType,
            isFrozen: false,
            isBurned: false,
            supply: uint8(amount)
        });

        /// Mint keys to `receiver`.
        _mint({ to: receiver, id: keyId, value: amount, data: "" });

        return keyId;
    }

    /**
     * @inheritdoc IKeys
     */
    function burnKeys(address holder, uint256 keyId, uint256 amount) external {
        /// Checks: Ensure the caller is a registered vault.
        if (!isRegistered[msg.sender]) revert CallerNotRegistered();

        /// Checks: Ensure that frozen keys cannot be destroyed.
        if (_keyConfig[keyId].isFrozen) revert KeysFrozen();

        /// Acknowledge that the keys have been burned.
        _keyConfig[keyId].isBurned = true;

        /// The `amount` does not require sanitization as the vault itself will keep track of
        /// how many keys are associated with it.
        _burn({ from: holder, id: keyId, value: amount });
    }

    /**
     * @inheritdoc IKeys
     */
    function lendKeys(address lendee, uint256 keyId, uint256 lendAmount, uint256 lendDuration) external {
        /// Checks: Ensure the key idenitifier is not frozen.
        if (_keyConfig[keyId].isFrozen) revert KeysFrozen();

        /// Checks: Ensure the lendee has valid access.
        IKYCRegistry.AccessType accessType = kycRegistry.accessType(lendee);
        if (accessType == IKYCRegistry.AccessType.BLOCKED) revert IKYCRegistry.InvalidAccessType();

        /// Checks: Ensure keys aren't being lended to self.
        if (msg.sender == lendee) revert CannotLendToSelf();

        /// Checks: Ensure the lendee does not already have an active lend for `keyId`.
        if (_activeLends[lendee][keyId].lender != address(0)) revert HasActiveLend();

        /// Checks: Ensure that a valid amount of keys are being lended.
        if (lendAmount == 0) revert ZeroLendAmount();

        /// Checks: Ensure a valid lend duration has been provided.
        if (lendDuration < MIN_LEND_DURATION || lendDuration > MAX_LEND_DURATION) revert InvalidLendDuration();

        uint40 lendExpiryTime = uint40(block.timestamp + lendDuration);

        /// Define the lending terms.
        /// forgefmt: disable-next-item
        _activeLends[lendee][keyId] = LendingTerms({
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
    function reclaimKeys(address lendee, uint256 keyId) external {
        /// Checks: Ensure the key idenitifier is not frozen.
        if (_keyConfig[keyId].isFrozen) revert KeysFrozen();

        /// Cache lending terms in memory.
        LendingTerms memory lendingTerms = _activeLends[lendee][keyId];

        /// Checks: Ensure lendee has an active lend.
        if (lendingTerms.expiryTime == 0) revert NoActiveLend();

        /// Checks: Ensure that the lending period has elapsed.
        if (lendingTerms.expiryTime > block.timestamp) revert LendStillActive();

        /// Clear lending terms.
        _activeLends[lendee][keyId] = LendingTerms({ lender: address(0), amount: 0, expiryTime: 0 });

        /// `keyId` does not need to be sanitized as `_safeTransferFrom` will fail if `keyId` does not exist.
        /// We use `_safeTransferFrom` here to circumvent the `isApprovedForAll` check but retain the zero address
        /// checks to prevent an alternative method of burning keys.
        _safeTransferFrom({ from: lendee, to: lendingTerms.lender, id: keyId, value: lendingTerms.amount, data: "" });
    }

    /**
     * @inheritdoc IKeys
     */
    function registerVault(address vault) external onlyRoles(FACTORY_ROLE) {
        isRegistered[vault] = true;
    }

    /**
     * @inheritdoc IKeys
     */
    function freezeKeys(uint256 keyId) external onlyRoles(ADMIN_ROLE) {
        _keyConfig[keyId].isFrozen = true;

        emit IKeys.KeyFrozen({ admin: msg.sender, keyId: keyId });
    }

    /**
     * @inheritdoc IKeys
     */
    function unfreezeKeys(uint256 keyId) external onlyRoles(ADMIN_ROLE) {
        _keyConfig[keyId].isFrozen = false;

        emit IKeys.KeyUnfrozen({ admin: msg.sender, keyId: keyId });
    }

    /**
     * Function used to set the key exchange address.
     */
    function setKeyExchange(address _keyExchange) external onlyOwner {
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
        if (_keyConfig[id].isFrozen) revert KeysFrozen();

        /// Checks: Ensure that `to` has a valid access type.
        IKYCRegistry.AccessType accessType = kycRegistry.accessType(to);
        if (accessType == IKYCRegistry.AccessType.BLOCKED) revert IKYCRegistry.InvalidAccessType();

        /// Checks: Ensure zero value transfers are not allowed.
        if (value == 0) revert ZeroKeyTransfer();

        /// Check the lending status of the key.
        LendingTerms memory lendingTerms = _activeLends[from][id];

        /// If `from` has no active lends associated with `id`.
        if (lendingTerms.lender == address(0)) {
            _safeTransferFrom(from, to, id, value, data);

            /// If some amount of keys are being transferred to the lender. We don't need to check
            /// the value here as we can guarantee that it is non-zero and a transfer of any non-zero
            /// amount of keys should clear the lending terms.
        } else if (to == lendingTerms.lender) {
            /// Calculate the amount of lended keys being returned to the lender.
            uint256 remainingKeys = lendingTerms.amount - value;
            /// Lend has been returned in full.
            if (remainingKeys == 0) {
                /// Clear lending terms.
                _activeLends[from][value] = LendingTerms({ lender: address(0), amount: 0, expiryTime: 0 });    
            } else {
                /// Update lending terms to reflect the remaining amount of keys on lend.
                _activeLends[from][value].amount = uint56(remainingKeys);
            }

            _safeTransferFrom(from, to, id, value, data);

            /// If a transfer is being attempted with a lend active to a non-lender.
        } else {
            /// Get the total number of keys held by `from` and then calculate how many 'free' keys
            /// `from` has. Free keys in this context refers to how many keys `from` owns that are not
            /// on lend.
            uint256 keysHeld = this.balanceOf({ account: from, id: id });
            uint256 freeKeys = keysHeld - lendingTerms.amount;

            /// If the number of keys being transferred exceeds the number of free keys owned by
            /// `from`, they shouldn't be able to move any keys.
            if (value > freeKeys) revert OverFreeKeyBalance();

            _safeTransferFrom(from, to, id, value, data);
        }

        // _safeTransferFrom(from, to, id, value, data);
    }

    function getKeyConfig(uint256 keyId) external view returns (KeyConfig memory) {
        return _keyConfig[keyId];
    }

    function activeLends(address lendee, uint256 keyId) external view returns (LendingTerms memory) {
        return _activeLends[lendee][keyId];
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
    function setURI(string calldata newURI) external onlyRoles(ADMIN_ROLE) {
        _setURI(newURI);
    }

}
