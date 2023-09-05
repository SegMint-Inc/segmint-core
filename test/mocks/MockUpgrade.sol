// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../src/factories/VaultFactory.sol";

contract MockUpgrade is VaultFactory {
    function nameAndVersion() external pure override returns (string memory name, string memory version) {
        name = "Upgraded Vault Factory";
        version = "2.0";
    }
}
