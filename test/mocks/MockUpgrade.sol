// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../src/factories/ServiceFactory.sol";

contract MockUpgrade is ServiceFactory {
    function nameAndVersion() external pure override returns (string memory name, string memory version) {
        name = "Upgraded Service Factory";
        version = "2.0";
    }
}
