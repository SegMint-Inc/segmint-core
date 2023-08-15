// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { OwnableRoles } from "solady/src/auth/OwnableRoles.sol";
import { ERC1155 } from "@openzeppelin/token/ERC1155/ERC1155.sol";
import { ISegMintKeys } from "./interfaces/ISegMintKeys.sol";
import { ISegMintKYCRegistry } from "./interfaces/ISegMintKYCRegistry.sol";
import { KYCRegistry, Vault } from "./types/DataTypes.sol";
import { Errors } from "./libraries/Errors.sol";

contract SegMintKeys is ISegMintKeys, OwnableRoles, ERC1155 {
    error HasActiveLend();
    error InvalidLendDuration();
    error CallerNotLender();
    error LendNotExpired();
    error OverFreeKeyBalance();
    error ZeroValueTransfer();
    error ZeroLendAmount();
    error SoulboundKey();

    uint256 private constant _MIN_LEND_DURATION = 1 days;
    uint256 private constant _MAX_LEND_DURATION = 365 days;

    ISegMintKYCRegistry public kycRegistry;
    address public keyExchange;

    mapping(address lendee => mapping(uint256 keyId => Lend lend)) public activeLends;

    struct Lend {
        address lender;
        uint56 amount;
        uint40 expiryTime;
    }

    modifier isApprovedVault() {
        /// Checks: Ensure the caller is an approved vault.
        if (!isApproved[msg.sender]) revert Errors.VaultNotApproved();
        _;
    }

    /// @dev Total number of unique keys in circulation.
    uint64 public uniqueKeys;

    mapping(address vault => bool approved) public isApproved;
    mapping(uint256 keyId => bool frozen) public isFrozen;

    // mapping(address account => Lend lend) public lending;
    mapping(uint256 keyId => mapping(address account => Lend lend)) public lending;

    /// forgefmt: disable-next-item
    constructor(
        address admin_,
        string memory uri_,
        ISegMintKYCRegistry kycRegistry_,
        address keyExchange_
    ) ERC1155(uri_) {
        _initializeOwner(msg.sender);
        _grantRoles(admin_, _ROLE_0);

        kycRegistry = kycRegistry_;
        keyExchange = keyExchange_;
    }

    function burnKeys(address holder, uint256 keyId, uint256 amount) external isApprovedVault {
        /// Checks: Ensure that frozen keys cannot be destroyed.
        if (isFrozen[keyId]) revert Errors.KeysFrozen();

        _burn({ from: holder, id: keyId, value: amount });
    }

    function createKeys(uint256 amount, address receiver, Vault.KeyType keyType) external returns (uint256) {
        /// Cache current key ID and increment.
        uint256 keyId = ++uniqueKeys;

        /// Mint `amount` of keys to `receiver`.
        _mint({ to: receiver, id: keyId, value: amount, data: "" });

        return keyId;
    }

    /**
     * Function used to lend keys to a specified account for `duration` period of time.
     */
    function lendKeys(
        address lendee,
        uint256 keyId,
        uint256 lendAmount,
        uint256 lendDuration
    ) external notFrozen(keyId) {
        /// Checks: Ensure that the lendee has a valid access type.
        KYCRegistry.AccessType accessType = kycRegistry.getAccessType(lendee);
        if (accessType == KYCRegistry.AccessType.BLOCKED) revert Errors.InvalidAccessType();
        // Checks: Ensure the lendee does not already have an active lend for `keyId`.
        if (activeLends[lendee][keyId].lender != address(0)) revert HasActiveLend();
        // Checks: Ensure that a valid amount has been provided.
        if (lendAmount == 0) revert ZeroLendAmount();
        // Checks: Ensure a valid lend duration has been provided.
        if (lendDuration < _MIN_LEND_DURATION || lendDuration > _MAX_LEND_DURATION) revert InvalidLendDuration();

        // Set lending terms.
        uint40 lendExpiryTime = uint40(block.timestamp + lendDuration);
        activeLends[lendee][keyId] = Lend({
            lender: msg.sender,
            amount: uint56(lendAmount),
            expiryTime: lendExpiryTime
        });

        // Key ID does not need to be sanitized as transfer will fail if it doesn't exist.
        // Same principle applies to amount.
        safeTransferFrom({
            from: msg.sender,
            to: lendee,
            id: keyId,
            value: lendAmount,
            data: ""
        });
    }

    /**
     * Function used to reclaim ALL lended keys from `lendee`.
     */
    function reclaimKeys(address lendee, uint256 keyId) external {
        // Checks: Ensure that the lend has expired.
        // TODO: Check to ensure that reclaim only after expiry is as intended.
        if (block.timestamp > activeLends[lendee][keyId].expiryTime) revert LendNotExpired();

        // Cache lend struct in memory.
        Lend memory lend = activeLends[lendee][keyId];

        // Clear lending terms.
        activeLends[lendee][keyId] = Lend({
            lender: address(0),
            amount: 0,
            expiryTime: 0
        });

        // Key ID does not need to be sanitized as transfer will fail if it doesn't exist.
        // NOTE: We use `_safeTransferFrom` here to circumvent the `isApprovedForAll` check.
        _safeTransferFrom({
            from: lendee,
            to: lend.lender,
            id: keyId,
            value: lend.amount,
            data: ""
        });
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
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes memory data
    ) public override notFrozen(id) {
        /// Checks: Ensure zero value transfers are not allowed.
        if (value == 0) revert ZeroValueTransfer();
        
        /// Checks: Ensure that `to` has a valid access type.
        KYCRegistry.AccessType accessType = kycRegistry.getAccessType(to);
        if (accessType == KYCRegistry.AccessType.BLOCKED) revert Errors.InvalidAccessType();

        /// Check the lending status of the key.
        Lend memory lend = activeLends[from][id];

        /// If `from` has no activeLends associated with `id`.
        if (lend.expiryTime == 0) {
            _safeTransferFrom(from, to, id, value, data);

        /// If some amount of keys are being transferred to the lender. We don't need to check
        /// the value here as we can guarantee that it is non-zero and a transfer of any non-zero
        /// amount of keys should clear the lending terms.
        } else if (to == lend.lender) {
            /// Clear lending terms.
            activeLends[from][value] = Lend({
                lender: address(0),
                amount: 0,
                expiryTime: 0
            });

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
    function isApprovedForAll(address account, address operator) public view override returns (bool) {
        if (operator == keyExchange) {
            return true;
        } else {
            return super.isApprovedForAll(account, operator);
        }
    }

    function _notFrozen(uint256 keyId) internal view returns (bool) {
        if (isFrozen[keyId]) revert Errors.KeysFrozen();
    }

    modifier notFrozen(uint256 keyId) {
        _notFrozen(keyId);
        _;
    }
}
