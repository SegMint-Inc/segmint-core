// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

/**
 * @title ISegMintSafe
 * @notice This contract is a safe that allows a group of users to lock and unlock assets
 * within this contract.
 */

interface ISegMintSafe {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Emitted when keys are created and binded to a safe.
     * @param safe Address of the safe in which keys have been binded to.
     * @param keyId Token ID of the newly binded keys.
     * @param amount Number of keys that have been binded.
     */
    event KeysCreated(address indexed safe, uint256 keyId, uint256 amount);

    /**
     * Emitted when keys are unbinded and burned from a safe.
     * @param safe Address of the safe whose keys have been unbinded.
     * @param keyId Token ID of the unbinded keys.
     * @param amount Number of keys that have been unbind.
     */
    event KeysBurned(address indexed safe, uint256 keyId, uint256 amount);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function initialize(address[] calldata signers_, uint256 quorum_) external;
}
