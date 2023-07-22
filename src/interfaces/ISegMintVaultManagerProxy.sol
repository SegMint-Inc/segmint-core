// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

/**
 * @title ISegMintVaultManagerProxy
 * @notice Interface for SegMintVaultManagerProxy.
 */

interface ISegMintVaultManagerProxy {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Function used to view the current implementation address.
     * @return implementation The current implementation address.
     */
    function implementation() external view returns (address);
}
