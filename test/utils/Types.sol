// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.19;

struct Users {
    // Default admin for all SegMint contracts.
    address payable admin;
    // KYC'd user within the US.
    address payable alice;
    // KYC'd user outside of the US.
    address payable bob;
    // Malicious user.
    address payable eve;
}
