// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../Base.t.sol";

contract SegMintFactoryProxyTest is Base {
    function setUp() public override {
        super.setUp();
    }

    /* Deployment Test */

    function test_SegMintFactoryProxy_Deployment() public {
        assertEq(factoryProxy.implementation(), address(factory));
    }
}
