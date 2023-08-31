// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./BaseTest.sol";

contract ServiceFactoryTest is BaseTest {
    function setUp() public override {
        super.setUp();
        kycUsers(); // KYC both Alice and Bob.

        /// Interface the proxy contract with the implementation so that calls are delegated.
        serviceFactory = ServiceFactory(address(serviceFactoryProxy));
    }

    function test_ServiceFactory_Deployment() public {
        bool result = serviceFactory.hasAllRoles({ user: users.admin, roles: serviceFactory.ADMIN_ROLE() });
        assertTrue(result);

        assertEq(serviceFactory.owner(), address(this));
        assertEq(serviceFactory.maVault(), address(maVault));
        assertEq(serviceFactory.saVault(), address(saVault));
        assertEq(serviceFactory.safe(), address(safe));
        assertEq(serviceFactory.signerRegistry(), signerRegistry);
        assertEq(serviceFactory.kycRegistry(), kycRegistry);
        assertEq(serviceFactory.keys(), keys);
    }

    // function test_CreateMultiAssetVault() public {
    //     bytes memory signature = getVaultCreateSignature({
    //         account: users.alice,
    //         accessType: kycRegistry.accessType({ account: users.alice }),
    //         nonce: 0,
    //         discriminator: "MAV"
    //     });

    //     hoax(users.alice, users.alice);
    //     serviceFactory.createMultiAssetVault(signature);

    //     (uint256 maVaultNonce,,) = serviceFactory.getNonces({ account: users.alice });
    //     assertEq(maVaultNonce, 1);

    //     address[] memory maVaults = serviceFactory.getMultiAssetVaults({ account: users.alice });
    //     assertEq(maVaults.length, 1);

    //     address maVault = maVaults[0];
    //     uint256 codeSize;
    //     assembly {
    //         codeSize := extcodesize(maVault)
    //     }

    //     assertGt(codeSize, 0);
    // }
}
