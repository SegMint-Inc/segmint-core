// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Base.sol";

contract ServiceFactoryProxyTest is Base {
    function setUp() public override {
        super.setUp();
    }

    function test_ServiceFactoryProxy_Deployment() public {
        assertEq(serviceFactoryProxy.implementation(), address(serviceFactoryImplementation));
    }
}
