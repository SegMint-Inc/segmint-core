// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * @title Multicall
 * @notice This contract allows the inheriting contract to execute calls to non-payable calls to
 * external addresses that are not the contract itself using the `multicall()` function. Intended
 * for token transfers of ERC-20, ERC-721 and ERC-1155 contracts and claiming airdrops for
 * respective tokens that the inheriting contract may posesses.
 */

abstract contract Multicall {

    /**
     * Thrown when the targets array differs in size to the data array.
     */
    error ArrayLengthMismatch();

    /**
     * THrown when the call to the target contract fails.
     */
    error CallFailed();

    /**
     * Thrown when the contract attempts to call itself.
     */
    error CannotCallSelf();

    /**
     * Function used to execute calls to external targets.
     * @param targets Array of target contract addresses.
     * @param payloads Array of encoded calldata payloads.
     * @dev This function is deliberately made non-payable to guard against double-spending.
     * Ref: https://www.paradigm.xyz/2021/08/two-rights-might-make-a-wrong
     */
    function multicall(
        address[] calldata targets,
        bytes[] calldata payloads
    ) public virtual returns (bytes[] memory results) {
        /// Checks: Ensure the targets array length matches the payloads array length.
        if (targets.length != payloads.length) revert ArrayLengthMismatch();

        /// TODO: Ensure contract can never call Keys contract?

        for (uint256 i = 0; i < targets.length; i++) {
            /// Checks: Ensure the contract is never calling itself.
            if (targets[i] == address(this)) revert CannotCallSelf();
            (bool success, bytes memory retdata) = targets[i].call(payloads[i]);

            /// NOTE: Will this be success on weird ERC-20 tokens such as USDT?
            if (!success) revert CallFailed();
            results[i] = retdata;
        }

        return results;
    }

}