// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

abstract contract Constants {
    address internal constant SIGNER = 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf;
    uint256 internal constant PRIVATE_KEY = 1;
    uint256 internal constant ERC1155_TOKEN_ID = 0;

    uint256 internal constant ADMIN_ROLE = 1;
    uint256 internal constant VAULT_MANAGER_ROLE = 2;

    uint256 internal constant ALICE_NFT_ID = 1;
    uint256 internal constant BOB_NFT_ID = 2;
    uint256 internal constant EVE_NFT_ID = 3;

    address payable internal constant RANDOM_VAULT = payable(0x83B4EEa426B7328eB3bE89cDb558F18BAF6A2Bf7);

    bytes4 internal constant UNAUTHORIZED_SELECTOR = 0x82b42900;

    uint40 internal constant UPGRADE_TIME_LOCK = 5 days;
}
