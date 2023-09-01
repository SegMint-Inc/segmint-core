// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../../src/factories/ServiceFactory.sol";

contract UpgradeTest is ServiceFactory {

    function nameAndVersion() external view override returns (string memory name, string memory version) {
        name = "Service Factory";
        version = "2.0";
    }

}