// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title AccessRoles
 * @notice This library contains all the valid roles within the protocol. Roles have been defined to mimic
 * {Solady.OwnableRoles} roles.
 */
library AccessRoles {
    uint256 public constant ADMIN_ROLE = 1 << 0;
    uint256 public constant FACTORY_ROLE = 1 << 1; 
}