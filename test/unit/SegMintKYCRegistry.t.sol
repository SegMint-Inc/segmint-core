// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../Base.t.sol";

contract SegMintKYCRegistryTest is Base {
    function setUp() public override {
        super.setUp();
    }

    /* Deployment Test */

    function test_SegMintKYCRegistry_Deployment() public {
        assertTrue(kycRegistry.hasAllRoles(users.admin, ADMIN_ROLE));
        assertEq(kycRegistry.owner(), address(this));
        assertEq(kycRegistry.signer(), SIGNER);
    }

    /* `initAccessType()` Tests */

    function test_InitAccessType_Restricted() public {
        KYCRegistry.AccessType accessType = KYCRegistry.AccessType.RESTRICTED;
        bytes memory signature = getAccessSignature(users.alice, accessType);

        hoax(users.alice, users.alice);
        vm.expectEmit();
        emit AccessTypeSet({ account: users.alice, accessType: accessType });
        kycRegistry.initAccessType({ signature: signature, newAccessType: accessType });

        assertEq(uint256(kycRegistry.getAccessType({ account: users.alice })), uint256(accessType), "AccessType");
    }

    function test_InitAccessType_Unrestricted() public {
        KYCRegistry.AccessType accessType = KYCRegistry.AccessType.UNRESTRICTED;
        bytes memory signature = getAccessSignature(users.bob, accessType);

        hoax(users.bob, users.bob);
        vm.expectEmit();
        emit AccessTypeSet({ account: users.bob, accessType: accessType });
        kycRegistry.initAccessType({ signature: signature, newAccessType: accessType });

        assertEq(uint256(kycRegistry.getAccessType({ account: users.bob })), uint256(accessType), "AccessType");
    }

    function test_InitAccessType_Fuzzed(address account) public {
        KYCRegistry.AccessType accessType =
            uint160(account) & 1 == 0 ? KYCRegistry.AccessType.RESTRICTED : KYCRegistry.AccessType.UNRESTRICTED;

        bytes memory signature = getAccessSignature(account, accessType);

        hoax(account, account);
        vm.expectEmit();
        emit AccessTypeSet({ account: account, accessType: accessType });
        kycRegistry.initAccessType({ signature: signature, newAccessType: accessType });

        assertEq(uint256(kycRegistry.getAccessType({ account: account })), uint256(accessType), "AccessType");
    }

    function testCannot_InitAccessType_AccessTypeSet() public {
        KYCRegistry.AccessType accessType = KYCRegistry.AccessType.RESTRICTED;
        bytes memory signature = getAccessSignature(users.alice, accessType);

        startHoax(users.alice, users.alice);
        kycRegistry.initAccessType({ signature: signature, newAccessType: accessType });
        vm.expectRevert(Errors.AccessTypeSet.selector);
        kycRegistry.initAccessType({ signature: signature, newAccessType: accessType });
    }

    function testCannot_InitAccessType_InvalidAccessType() public {
        KYCRegistry.AccessType accessType = KYCRegistry.AccessType.BLOCKED;
        bytes memory signature = getAccessSignature(users.alice, accessType);

        hoax(users.alice, users.alice);
        vm.expectRevert(Errors.InvalidAccessType.selector);
        kycRegistry.initAccessType({ signature: signature, newAccessType: accessType });
    }

    function testCannot_InitAccessType_SignerMismatch() public {
        hoax(users.admin, users.admin);
        kycRegistry.setSigner(address(0));

        KYCRegistry.AccessType accessType = KYCRegistry.AccessType.RESTRICTED;
        bytes memory signature = getAccessSignature(users.alice, accessType);

        hoax(users.alice, users.alice);
        vm.expectRevert(Errors.SignerMismatch.selector);
        kycRegistry.initAccessType({ signature: signature, newAccessType: accessType });
    }

    /* `modifyAccessType()` Tests */

    function test_ModifyAccessType() public {
        KYCRegistry.AccessType accessType = KYCRegistry.AccessType.RESTRICTED;

        startHoax(users.admin, users.admin);
        vm.expectEmit();
        emit AccessTypeModified({ admin: users.admin, account: users.alice, accessType: accessType });
        kycRegistry.modifyAccessType({ account: users.alice, newAccessType: accessType });
        assertEq(uint256(kycRegistry.getAccessType({ account: users.alice })), uint256(accessType), "AccessType");

        accessType = KYCRegistry.AccessType.UNRESTRICTED;

        vm.expectEmit();
        emit AccessTypeModified({ admin: users.admin, account: users.bob, accessType: accessType });
        kycRegistry.modifyAccessType({ account: users.bob, newAccessType: accessType });
        assertEq(uint256(kycRegistry.getAccessType({ account: users.bob })), uint256(accessType), "AccessType");
    }

    function testCannot_ModifyAccessType_Unauthorized() public {
        hoax(users.eve, users.eve);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        kycRegistry.modifyAccessType({ account: users.eve, newAccessType: KYCRegistry.AccessType.UNRESTRICTED });
    }

    /* `setSigner()` Tests */

    function test_SetSigner_Fuzzed(address newSigner) public {
        hoax(users.admin, users.admin);
        kycRegistry.setSigner({ newSigner: newSigner });
        assertEq(kycRegistry.signer(), newSigner);
    }

    function testCannot_SetSigner_Unauthorized() public {
        hoax(users.eve, users.eve);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        kycRegistry.setSigner({ newSigner: users.eve });
    }
}
