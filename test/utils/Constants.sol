// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

abstract contract Constants {
    address internal constant SIGNER = 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf;
    uint256 internal constant PRIVATE_KEY = 1;
    uint256 internal constant ADMIN_ROLE = 0x4a4566510e9351b52a3e4f6550fc68d8577350bec07d7a69da4906b0efe533bc;

    bytes4 internal constant UNAUTHORIZED_SELECTOR = 0x82b42900;
}
