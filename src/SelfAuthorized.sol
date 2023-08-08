// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { Errors } from "./libraries/Errors.sol";

/**
 * @title SelfAuthorized
 * @notice From Gnosis Safe's `SelfAuthorized`.
 * https://github.com/safe-global/safe-contracts/blob/main/contracts/common/SelfAuthorized.sol
 */

abstract contract SelfAuthorized {
    function _sanityCheck() private view {
        /// Checks: Ensure that `msg.sender` is the caller itself.
        if (msg.sender != address(this)) revert Errors.InvalidCaller();
    }

    modifier selfAuthorized() {
        _sanityCheck();
        _;
    }
}
