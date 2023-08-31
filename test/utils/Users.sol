// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

struct User {
    address account;
    uint256 privateKey;
}

struct Users {
    /// Default administrator.
    address admin;
    /// Restricted KYC user.
    User alice;
    /// Unrestricted KYC user.
    User bob;
    /// Malicious user with no KYC verification.
    User eve;
}