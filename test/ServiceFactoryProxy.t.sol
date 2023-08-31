// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./BaseTest.sol";

contract ServiceFactoryProxyTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_ServiceFactoryProxy_Deployment() public {
        address implementation = serviceFactoryProxy.implementation();
        assertEq(implementation, address(serviceFactory));
    }
}
