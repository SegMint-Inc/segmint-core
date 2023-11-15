// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { OwnableRoles } from "@solady/src/auth/OwnableRoles.sol";
import { ERC1155 } from "@openzeppelin/token/ERC1155/ERC1155.sol";
import { ReentrancyGuard } from "@openzeppelin/security/ReentrancyGuard.sol";
import { IKeys } from "./interfaces/IKeys.sol";
import { IAccessRegistry } from "./interfaces/IAccessRegistry.sol";
import { OperatorFilter } from "./handlers/OperatorFilter.sol";
import { VaultType, KeyConfig } from "./types/DataTypes.sol";

/**
 * @title Keys
 * @notice Protocol ERC1155 token that provides functionality for key lending.
 */

contract Keys is IKeys, OwnableRoles, ERC1155, OperatorFilter, ReentrancyGuard {
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

    /// Mapping of active lends.
    mapping(address lendee => mapping(uint256 keyId => LendingTerms lendingTerm)) private _activeLends;

    /// Interface for access registry.
    IAccessRegistry public accessRegistry;

    /// Address of the key exchange.
    address public keyExchange;

    /// Counts the number of unique keys created.
    uint256 public keysCreated;

    mapping(address vault => bool registered) public isRegistered;

    /**
     * Ensure the caller is a registered vault. This modifier calls an internal function
     * to reduce bytecode size.
     */
    modifier isVault() {
        _isVault();
        _;
    }

    constructor(address admin_, string memory uri_, IAccessRegistry accessRegistry_) ERC1155(uri_) {
        if (admin_ == address(0) || address(accessRegistry_) == address(0)) revert ZeroAddressInvalid();

        _initializeOwner(msg.sender);
        _grantRoles(admin_, ADMIN_ROLE);

        accessRegistry = accessRegistry_;
    }

    /**
     * @inheritdoc IKeys
     * @dev This function should only be callable by vaults that have been created through the Vault Factory.
     */
    function createKeys(uint256 amount, address receiver, VaultType vaultType) external isVault returns (uint256) {
        /// Checks: Ensure a valid amount of keys are being created.
        if (amount == 0 || amount > MAX_KEYS) revert InvalidKeyAmount();

        /// Increment the number of keys created and push this value to the stack. The pre-increment
        /// is done to ensure that keys with an ID of 0 are never created.
        uint256 keyId = ++keysCreated;

        /// Update the key bindings associated with the vault. `amount` can be safely casted to type uint8
        /// as this value is bounded between 1 and `MAX_KEYS`.
        _keyConfig[keyId] = KeyConfig({
            creator: receiver,
            vaultType: vaultType,
            isFrozen: false,
            isBurned: false,
            supply: uint8(amount)
        });

        /// Mint keys to `receiver`.
        _mint({ to: receiver, id: keyId, amount: amount, data: "" });

        return keyId;
    }

    /**
     * @inheritdoc IKeys
     * @dev This function should only be callable by vaults that have been created through the Vault Factory.
     */
    function burnKeys(address holder, uint256 keyId, uint256 amount) external isVault {
        /// Checks: Ensure that frozen keys cannot be destroyed.
        if (_keyConfig[keyId].isFrozen) revert KeysFrozen();

        /// Acknowledge that the keys have been burned.
        _keyConfig[keyId].isBurned = true;

        /// Unregister vault.
        isRegistered[msg.sender] = false;

        /// The `amount` does not require sanitization as the vault itself will keep track of
        /// how many keys are associated with it.
        _burn({ from: holder, id: keyId, amount: amount });
    }

    /**
     * @inheritdoc IKeys
     */
    function lendKeys(address lendee, uint256 keyId, uint256 lendAmount, uint256 lendDuration) external {
        /// Checks: Ensure `lendee` is not the zero address to prevent excess gas consumption.
        if (lendee == address(0)) revert ZeroAddressInvalid();

        /// Checks: Ensure the key idenitifier is not frozen.
        if (_keyConfig[keyId].isFrozen) revert KeysFrozen();

        /// Checks: Ensure the lendee has valid access.
        IAccessRegistry.AccessType accessType = accessRegistry.accessType(lendee);
        if (accessType == IAccessRegistry.AccessType.BLOCKED) revert IAccessRegistry.InvalidAccessType();

        /// Checks: Ensure keys aren't being lended to self.
        if (msg.sender == lendee) revert CannotLendToSelf();

        /// Checks: Ensure the lendee does not already have an active lend for `keyId`.
        if (_activeLends[lendee][keyId].lender != address(0)) revert HasActiveLend();

        /// Checks: Ensure that a valid amount of keys are being lended.
        if (lendAmount == 0) revert ZeroLendAmount();

        /// Checks: Ensure a valid lend duration has been provided.
        if (lendDuration < MIN_LEND_DURATION || lendDuration > MAX_LEND_DURATION) revert InvalidLendDuration();

        /// Checks: Ensure the keys being lended are not lended themselves.
        uint256 ownedKeys = balanceOf(msg.sender, keyId) - _activeLends[msg.sender][keyId].amount;
        if (lendAmount > ownedKeys) revert CannotLendOutLendedKeys();

        uint40 lendExpiryTime = uint40(block.timestamp + lendDuration);

        /// Define the lending terms.
        /// forgefmt: disable-next-item
        _activeLends[lendee][keyId] = LendingTerms({
            lender: msg.sender,
            amount: uint56(lendAmount),
            expiryTime: lendExpiryTime
        });

        /// `keyId` and `lendAmount` do not need to be sanitized as `safeTransferFrom` will fail
        /// if either `keyId` does not exist of `lendAmount` exceeds the lenders balance.
        _safeTransferFrom({ from: msg.sender, to: lendee, id: keyId, amount: lendAmount, data: "" });
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
        _safeTransferFrom({ from: lendee, to: lendingTerms.lender, id: keyId, amount: lendingTerms.amount, data: "" });
    }

    /**
     * @inheritdoc IKeys
     */
    function registerVault(address vault) external onlyRoles(FACTORY_ROLE) {
        if (vault == address(0)) revert ZeroAddressInvalid();
        isRegistered[vault] = true;
        emit VaultRegistered({ registeredVault: vault });
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
     * @inheritdoc IKeys
     */
    function getKeyConfig(uint256 keyId) external view returns (KeyConfig memory) {
        return _keyConfig[keyId];
    }

    /**
     * @inheritdoc IKeys
     */
    function activeLends(address lendee, uint256 keyId) external view returns (LendingTerms memory) {
        return _activeLends[lendee][keyId];
    }

    /**
     * @inheritdoc IKeys
     */
    function clearLendingTerms(address lendee, uint256 keyId) external {
        /// Checks: Ensure the caller is the Key Exchange.
        if (msg.sender != keyExchange) revert CallerNotExchange();
        _activeLends[lendee][keyId] = LendingTerms({ lender: address(0), amount: 0, expiryTime: 0 });
    }

    /**
     * Function used to set the `accessRegistry` address.
     */
    function setAccessRegistry(IAccessRegistry newAccessRegistry) external onlyRoles(ADMIN_ROLE) {
        if (address(newAccessRegistry) == address(0)) revert ZeroAddressInvalid();

        IAccessRegistry oldAccessRegistry = accessRegistry;
        accessRegistry = newAccessRegistry;

        emit AccessRegistryUpdated({ oldAccessRegistry: oldAccessRegistry, newAccessRegistry: newAccessRegistry });
    }

    /**
     * Function used to set the `keyExchange` address.
     */
    function setKeyExchange(address newKeyExchange) external onlyOwner {
        if (newKeyExchange == address(0)) revert ZeroAddressInvalid();

        address oldKeyExchange = keyExchange;
        keyExchange = newKeyExchange;

        /// Authorize the Key Exchange as whitelisted operator, this operation does NOT clear
        /// the previous Key Exchange's operator status.
        _updateOperatorStatus({ operator: newKeyExchange, isAllowed: true });

        emit KeyExchangeUpdated({ oldKeyExchange: oldKeyExchange, newKeyExchange: newKeyExchange });
    }

    /**
     * Function used to set a new URI associated with key metadata.
     */
    function setURI(string calldata newURI) external onlyRoles(ADMIN_ROLE) {
        _setURI(newURI);
        emit URIUpdated({ newURI: newURI });
    }

    /**
     * Function used to update an operators status.
     */
    function updateOperatorStatus(address operator, bool isAllowed) external onlyRoles(ADMIN_ROLE) {
        _updateOperatorStatus(operator, isAllowed);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     ERC1155 OVERRIDES                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Overriden to provide additional checks prior to transfer.
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data)
        public
        override
        filterOperator(from)
        nonReentrant
    {
        /// Checks: Ensure that `to` has a valid access type.
        IAccessRegistry.AccessType accessType = accessRegistry.accessType(to);
        if (accessType == IAccessRegistry.AccessType.BLOCKED) revert IAccessRegistry.InvalidAccessType();

        /// Checks: Ensure the key idenitifier is not frozen.
        if (_keyConfig[id].isFrozen) revert KeysFrozen();

        /// Checks: Ensure zero value transfers are not allowed.
        if (value == 0) revert ZeroKeyTransfer();

        /// Handles token transfers for addresses that may have a lend active.
        _checkLends(from, to, id, value);

        /// Transfer tokens.
        super.safeTransferFrom(from, to, id, value, data);
    }

    /**
     * Overriden to provide additional checks prior to transfer.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public override filterOperator(from) nonReentrant {
        /// Checks: Ensure `ids` and `amounts` are equivalent in length.
        if (ids.length != amounts.length) revert ArrayLengthMismatch();

        /// Checks: Ensure that `to` has a valid access type.
        IAccessRegistry.AccessType accessType = accessRegistry.accessType(to);
        if (accessType == IAccessRegistry.AccessType.BLOCKED) revert IAccessRegistry.InvalidAccessType();

        /// Checks: Ensure that each `id` of `ids` can be transferred.
        for (uint256 i = 0; i < ids.length; i++) {
            /// Cache variables used multiple times.
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            /// Checks: Ensure the key idenitifier is not frozen.
            if (_keyConfig[id].isFrozen) revert KeysFrozen();

            /// Checks: Ensure zero value transfers are not allowed.
            if (amount == 0) revert ZeroKeyTransfer();

            /// Handles token transfers for addresses that may have a lend active.
            _checkLends(from, to, id, amount);
        }

        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     * This function has been overridden to ensure that the key exchange can perform buy outs.
     */
    function isApprovedForAll(address account, address operator) public view override returns (bool) {
        return operator == keyExchange ? true : super.isApprovedForAll(account, operator);
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public override filterOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       INTERNAL LOGIC                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function _isVault() internal view {
        if (!isRegistered[msg.sender]) revert CallerNotVault();
    }

    /**
     * Function used to handle token transfers from accounts that *may* have an active lend.
     */
    function _checkLends(address from, address to, uint256 id, uint256 amount) internal {
        /// Check the lending status of the key.
        LendingTerms memory lendingTerms = _activeLends[from][id];

        /// There are 3 cases to be wary of.
        /// 1. The `from` address has no active lends for key `id`.
        /// 2. The `from` address has an active lend, but is sending keys to the lender.
        /// 3. The `from` address has an active lend, but is not sending keys to lender.

        /// Case #1 - No further action required.
        if (lendingTerms.lender == address(0)) {
            /// Case #2
        } else if (to == lendingTerms.lender) {
            /// Calculate the amount of lended keys being returned to the lender.
            uint256 remainingKeys = lendingTerms.amount - amount;
            /// Lended keys have been returned in full.
            if (remainingKeys == 0) {
                /// Clear lending terms.
                _activeLends[from][id] = LendingTerms({ lender: address(0), amount: 0, expiryTime: 0 });
            } else {
                /// Update lending terms to reflect the remaining amount of keys on lend.
                _activeLends[from][id].amount = uint56(remainingKeys);
            }

            /// Case #3
        } else {
            /// Get the total number of keys held by `from` and then calculate how many 'free' keys
            /// `from` has. Free keys in this context refers to how many keys `from` owns that are not
            /// on lend.
            uint256 freeKeys = this.balanceOf(from, id) - lendingTerms.amount;

            /// If the number of keys being transferred exceeds the number of free keys owned by
            /// `from`, they shouldn't be able to move any keys as this would result in lended keys being
            /// transferred.
            if (amount > freeKeys) revert CannotTransferLendedKeys();
        }
    }
}
