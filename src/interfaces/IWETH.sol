// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IWETH {
    function transferFrom(address src, address dst, uint256 wad) external returns (bool);

    function approve(address guy, uint256 wad) external returns (bool);
}
