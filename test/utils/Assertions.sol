// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import { ISignerRegistry } from "../../src/interfaces/ISignerRegistry.sol";
import { IKYCRegistry } from "../../src/interfaces/IKYCRegistry.sol";
import { IKeyExchange } from "../../src/interfaces/IKeyExchange.sol";
import { IKeys } from "../../src/interfaces/IKeys.sol";
import { IMAVault } from "../../src/interfaces/IMAVault.sol";
import { ISAVault } from "../../src/interfaces/ISAVault.sol";
// import { ISafe } from "../src/interfaces/ISafe.sol";
// import { IWETH } from "../src/interfaces/IWETH.sol";

abstract contract Assertions is Test {
    /// Asserts two {ISignerRegistry} interface values match.
    function assertEq(ISignerRegistry a, ISignerRegistry b) internal {
        assertEq(address(a), address(b));
    }

    /// Asserts two {IKYCRegistry} interface values match.
    function assertEq(IKYCRegistry a, IKYCRegistry b) internal {
        assertEq(address(a), address(b));
    }

    /// Asserts two {IKYCRegistry.AccessType} enum values match.
    function assertEq(IKYCRegistry.AccessType a, IKYCRegistry.AccessType b) internal {
        assertEq(uint256(a), uint256(b));
    }

    /// Assets two {IKYC} interface values match.
    function assertEq(IKeys a, IKeys b) internal {
        assertEq(address(a), address(b));
    }

    /// Assets two {IMAVault} interface values match.
    function assertEq(IMAVault a, IMAVault b) internal {
        assertEq(address(a), address(b));
    }

    /// Assets two {ISAVault} interface values match.
    function assertEq(ISAVault a, ISAVault b) internal {
        assertEq(address(a), address(b));
    }

    /// Assets two {IKeyExchange} interface values match.
    function assertEq(IKeyExchange a, IKeyExchange b) internal {
        assertEq(address(a), address(b));
    }
}
