// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Base.sol";

contract ServiceFactoryTest is Base {
    function setUp() public override {
        super.setUp();

        // Grant restricted access to Alice.
        IKYCRegistry.AccessType accessType = IKYCRegistry.AccessType.RESTRICTED;
        hoax(users.alice, users.alice);
        kycRegistry.initAccessType({
            signature: getAccessSignature({ account: users.alice, deadline: block.timestamp, accessType: accessType }),
            deadline: block.timestamp,
            newAccessType: accessType
        });
    }

    function test_ServiceFactory_Deployment() public {
        assertTrue(serviceFactoryProxied.hasAllRoles({ user: users.admin, roles: ADMIN_ROLE }));
        assertEq(address(serviceFactoryProxied.mavImplementation()), address(maVault));
        assertEq(address(serviceFactoryProxied.savImplementation()), address(saVault));
        assertEq(address(serviceFactoryProxied.safeImplementation()), address(safe));
        assertEq(address(serviceFactoryProxied.signerRegistry()), address(signerRegistry));
        assertEq(address(serviceFactoryProxied.kycRegistry()), address(kycRegistry));
        assertEq(address(serviceFactoryProxied.keys()), address(keys));
    }

    function test_CreateMultiAssetVault() public {
        bytes memory signature = getVaultCreateSignature({
            account: users.alice,
            accessType: kycRegistry.accessType({ account: users.alice }),
            nonce: 0,
            discriminator: "MAV"
        });

        hoax(users.alice, users.alice);
        serviceFactoryProxied.createMultiAssetVault(signature);

        (uint256 maVaultNonce,,) = serviceFactoryProxied.getNonces({ account: users.alice });
        assertEq(maVaultNonce, 1);

        address[] memory maVaults = serviceFactoryProxied.getMultiAssetVaults({ account: users.alice });
        assertEq(maVaults.length, 1);

        address maVault = maVaults[0];
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(maVault)
        }

        assertGt(codeSize, 0);
    }
}
