// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

/**
 * @title NonceManager
 * @notice Managers account nonces for the Key Exchange. Incrementing a user nonce invalidates
 * all orders and bids associated with the account. Inspired from SeaPorts `ReferenceCounterManager`.
 * ref: https://github.com/ProjectOpenSea/seaport/blob/main/reference/lib/ReferenceCounterManager.sol#L25
 */

abstract contract NonceManager {
    /**
     * Event for nonce increments.
     */
    event NonceUpdated(address indexed account, uint256 newNonce);

    /**
     * Mapping of an account to a nonce.
     */
    mapping(address account => uint256 nonce) internal _nonces;

    /**
     * Function used to increment the nonce associated with an account by a
     * quasi-random number. The reasoning for doing this in such a way is to
     * prevent orders from being activated if a future and predictable nonce is signed.
     */
    function _incrementNonce() internal {
        // Use second half of the previous block hash as a quasi-random number.
        uint256 quasiRandomNumber = uint256(blockhash(block.number - 1)) >> 128;

        // Retrieve the original counter value.
        uint256 originalNonce = _nonces[msg.sender];

        // Increment current counter for the supplied offerer.
        uint256 newNonce = quasiRandomNumber + originalNonce;

        // Update the counter with the new value.
        _nonces[msg.sender] = newNonce;

        // Emit nonce updated event.
        emit NonceUpdated({ account: msg.sender, newNonce: newNonce });
    }

    /**
     * Function used to view the current nonce associated with the account.
     * @param account Address to check the current nonce value of.
     */
    function _getNonce(address account) internal view returns (uint256) {
        return _nonces[account];
    }
}
