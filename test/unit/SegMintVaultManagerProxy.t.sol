// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../Base.t.sol";

contract SegMintVaultManagerProxyTest is Base {
    function setUp() public override {
        super.setUp();
    }

    /* Deployment Test */

    function test_SegMintVaultManagerProxy_Deployment() public {
        assertEq(vaultManagerProxy.implementation(), address(vaultManager));
    }
}
