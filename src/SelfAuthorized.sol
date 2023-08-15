// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import { ISelfAuthorized } from "./interfaces/ISelfAuthorized.sol";

/**
 * @title SelfAuthorized
 * @notice See documentation from {ISelfAuthorized}.
 */

abstract contract SelfAuthorized is ISelfAuthorized {
    function _sanityCheck() private view {
        /// Checks: Ensure that `msg.sender` is the address itself.
        if (msg.sender != address(this)) revert CallerNotSelf();
    }

    modifier selfAuthorized() {
        _sanityCheck();
        _;
    }
}
