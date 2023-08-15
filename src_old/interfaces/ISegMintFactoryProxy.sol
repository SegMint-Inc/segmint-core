// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * @title ISegMintFactoryProxy
 * @notice This contract is a proxy for {SegMintFactory}.
 */

interface ISegMintFactoryProxy {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         FUNCTIONS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Function used to view the current implementation address.
     */
    function implementation() external view returns (address);
}
