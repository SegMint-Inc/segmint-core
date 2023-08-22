// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * @title IKeys
 * @notice This contract implements the ERC-1155 keys contract.
 */

interface IKeys {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERRORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Thrown when an account already has an active lend for the specified key ID.
     */
    error HasActiveLend();

    /**
     * Thrown when trying to lend a key outside of the defined lending duration boundaries.
     */
    error InvalidLendDuration();

    /**
     * Thrown when trying to reclaim keys before the defined lending period has elapsed.
     */
    error LendStillActive();

    /**
     * Thrown when trying to relcaim keys for a lendee with no active lend for key ID.
     */
    error NoActiveLend();

    /**
     * Thrown when trying to transfer an amount of keys that exceeds the accounts free key balance.
     */
    error OverFreeKeyBalance();

    /**
     * Thrown when trying to transfer a zero amount of keys.
     */
    error ZeroKeyTransfer();

    /**
     * Thrown when trying to create a zero amount of keys.
     */
    error ZeroKeyAmount();

    /**
     * Thrown when trying to transfer a key that has been provided on a lend.
     */
    error SoulboundKey();

    /**
     * Thrown when trying to transfer keys that have been frozen.
     */
    error KeysFrozen();

    /**
     * Thrown when an non-registered address attempts to create keys.
     */
    error CallerNotRegistered();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Emitted when a specific key identifier is frozen.
     * @param admin Address of the admin that froze the keys.
     * @param keyId Key identifier that was frozen.
     */
    event KeyFrozen(address indexed admin, uint256 keyId);

    /**
     * Emitted when a specific key identifier is unfrozen.
     * @param admin Address of the admin that unfroze the keys.
     * @param keyId Key ID that was unfrozen.
     */
    event KeyUnfrozen(address indexed admin, uint256 keyId);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STRUCTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Struct encapsulating the information associated with a keys lending terms.
     * @param lender The address that initiated the lend.
     * @param amount Number of keys that were provided on lend.
     * @param expiryTime Timestamp of when the lend expires.
     */
    struct LendingTerms {
        address lender;
        uint56 amount;
        uint40 expiryTime;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Function used to create keys and return the key ID associated with them.
     * @param amount Number of keys being created.
     * @param receiver Address receiving the newly created keys.
     */
    function createKeys(uint256 amount, address receiver) external returns (uint256);

    /**
     * Function used to burn keys.
     * @param holder Account that is burning the keys.
     * @param keyId Unique key identifier.
     * @param amount Number of keys being burnt.
     */
    function burnKeys(address holder, uint256 keyId, uint256 amount) external;

    /**
     * Function used to lend keys out to a lendee.
     * @param lendee Account receiving the keys.
     * @param keyId Unique key identifier.
     * @param lendAmount Number of keys being lent out.
     * @param lendDuration Total time the lendee has access to the keys for.
     */
    function lendKeys(address lendee, uint256 keyId, uint256 lendAmount, uint256 lendDuration) external;

    /**
     * Function used to reclaim all keys from a lendee.
     * @param lendee Account in possession of the lended keys.
     * @param keyId Unique key identifier.
     */
    function reclaimKeys(address lendee, uint256 keyId) external;

    /**
     * Function used to register a vault to allow for key creation.
     * @param vault Address of the vault being registered.
     */
    function registerVault(address vault) external;

    /**
     * Function used to freeze keys.
     * @param keyId Unique key identifier.
     */
    function freezeKeys(uint256 keyId) external;

    /**
     * Function used to unfreeze keys.
     * @param keyId Unique key identifier.
     */
    function unfreezeKeys(uint256 keyId) external;

    /**
     * Function used to view the original key creator.
     * @param keyId Unique key identifier.
     */
    function creatorOf(uint256 keyId) external view returns (address);
}