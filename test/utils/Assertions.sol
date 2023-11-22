// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/Test.sol";

import { IDelegateRegistry } from "@delegate-registry/src/IDelegateRegistry.sol";
import { ISignerRegistry } from "../../src/interfaces/ISignerRegistry.sol";
import { IAccessRegistry } from "../../src/interfaces/IAccessRegistry.sol";
import { IKeyExchange } from "../../src/interfaces/IKeyExchange.sol";
import { IKeys } from "../../src/interfaces/IKeys.sol";
import { IMAVault } from "../../src/interfaces/IMAVault.sol";
import { ISAVault } from "../../src/interfaces/ISAVault.sol";
import { AssetClass, VaultType } from "../../src/types/DataTypes.sol";

abstract contract Assertions is Test {
    /// Asserts two {ISignerRegistry} interface values match.
    function assertEq(ISignerRegistry a, ISignerRegistry b) internal {
        assertEq(address(a), address(b));
    }

    /// Asserts two {IAccessRegistry} interface values match.
    function assertEq(IAccessRegistry a, IAccessRegistry b) internal {
        assertEq(address(a), address(b));
    }

    /// Asserts two {IAccessRegistry.AccessType} enum values match.
    function assertEq(IAccessRegistry.AccessType a, IAccessRegistry.AccessType b) internal {
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

    /// Asserts two {AssetClass} enum values match.
    function assertEq(AssetClass a, AssetClass b) internal {
        assertEq(uint256(a), uint256(b));
    }

    /// Assets two {VaultType} enum values match.
    function assertEq(VaultType a, VaultType b) internal {
        assertEq(uint256(a), uint256(b));
    }

    /// Assets two {IKeyExchange.MarketType} enum values match.
    function assertEq(IKeyExchange.MarketType a, IKeyExchange.MarketType b) internal {
        assertEq(uint256(a), uint256(b));
    }

    /// Assets two {IKeyExchange.Status} enum values match.
    function assertEq(IKeyExchange.Status a, IKeyExchange.Status b) internal {
        assertEq(uint256(a), uint256(b));
    }

    /// Assets two {IDelegateRegistry.DelegationType} enums values match.
    function assertEq(IDelegateRegistry.DelegationType a, IDelegateRegistry.DelegationType b) internal {
        assertEq(uint256(a), uint256(b));
    }
}
