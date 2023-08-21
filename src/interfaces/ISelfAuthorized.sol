// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * @title ISelfAuthorized
 * @notice Directly from Gnosis Safe's `SelfAuthorized`.
 * https://github.com/safe-global/safe-contracts/blob/main/contracts/common/SelfAuthorized.sol
 */

interface ISelfAuthorized {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERRORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Thrown when the caller is not the address itself.
     */
    error CallerNotSelf();
}
