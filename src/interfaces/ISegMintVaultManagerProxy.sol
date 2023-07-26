// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

/**
 * @title ISegMintVaultManagerProxy
 * @notice This contract is a proxy for {SegMintVaultManager}.
 */

interface ISegMintVaultManagerProxy {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Function used to view the current implementation address.
     */
    function implementation() external view returns (address);
}
