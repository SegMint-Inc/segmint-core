// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

struct Users {
    /// Default administrator for all smart contracts.
    address payable admin;
    /// Restricted KYC user.
    address payable alice;
    /// Unrestricted KYC user.
    address payable bob;
    /// Malicious user with no KYC verification.
    address payable eve;
}
