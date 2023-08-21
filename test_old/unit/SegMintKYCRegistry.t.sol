// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../Base.t.sol";

contract SegMintKYCRegistryTest is Base {
    function setUp() public override {
        super.setUp();
    }

    /* Deployment Test */

    function test_SegMintKYCRegistry_Deployment() public {
        assertTrue(kycRegistry.hasAllRoles(users.admin, ADMIN_ROLE));
        assertEq(kycRegistry.owner(), address(this));
        assertEq(address(kycRegistry.signerModule()), address(signerModule));
    }

    /* `initAccessType()` Tests */

    function test_InitAccessType_Restricted() public {
        KYCRegistry.AccessType accessType = KYCRegistry.AccessType.RESTRICTED;
        bytes memory signature = getAccessSignature(users.alice, accessType);

        hoax(users.alice, users.alice);
        vm.expectEmit({
            checkTopic1: true,
            checkTopic2: true,
            checkTopic3: false,
            checkData: true,
            emitter: address(kycRegistry)
        });
        emit AccessTypeSet({ account: users.alice, accessType: accessType });
        kycRegistry.initAccessType({ signature: signature, newAccessType: accessType });

        assertEq(uint256(kycRegistry.getAccessType({ account: users.alice })), uint256(accessType), "AccessType");
    }

    function test_InitAccessType_Unrestricted() public {
        KYCRegistry.AccessType accessType = KYCRegistry.AccessType.UNRESTRICTED;
        bytes memory signature = getAccessSignature(users.bob, accessType);

        hoax(users.bob, users.bob);
        vm.expectEmit({
            checkTopic1: true,
            checkTopic2: true,
            checkTopic3: false,
            checkData: true,
            emitter: address(kycRegistry)
        });
        emit AccessTypeSet({ account: users.bob, accessType: accessType });
        kycRegistry.initAccessType({ signature: signature, newAccessType: accessType });

        assertEq(uint256(kycRegistry.getAccessType({ account: users.bob })), uint256(accessType), "AccessType");
    }

    function test_InitAccessType_Fuzzed(address account) public {
        KYCRegistry.AccessType accessType =
            uint160(account) & 1 == 0 ? KYCRegistry.AccessType.RESTRICTED : KYCRegistry.AccessType.UNRESTRICTED;

        bytes memory signature = getAccessSignature(account, accessType);

        hoax(account, account);
        vm.expectEmit({
            checkTopic1: true,
            checkTopic2: true,
            checkTopic3: false,
            checkData: true,
            emitter: address(kycRegistry)
        });
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
        signerModule.setSigner(address(0));

        KYCRegistry.AccessType accessType = KYCRegistry.AccessType.RESTRICTED;
        bytes memory signature = getAccessSignature(users.alice, accessType);

        hoax(users.alice, users.alice);
        vm.expectRevert(Errors.SignerMismatch.selector);
        kycRegistry.initAccessType({ signature: signature, newAccessType: accessType });
    }

    /* `modifyAccessType()` Tests */

    function test_ModifyAccessType() public {
        KYCRegistry.AccessType oldAccessType = KYCRegistry.AccessType.BLOCKED;
        KYCRegistry.AccessType newAccessType = KYCRegistry.AccessType.RESTRICTED;

        startHoax(users.admin, users.admin);
        vm.expectEmit({
            checkTopic1: true,
            checkTopic2: true,
            checkTopic3: false,
            checkData: true,
            emitter: address(kycRegistry)
        });
        emit AccessTypeModified({
            admin: users.admin,
            account: users.alice,
            oldAccessType: oldAccessType,
            newAccessType: newAccessType
        });
        kycRegistry.modifyAccessType({ account: users.alice, newAccessType: newAccessType });
        assertEq(uint256(kycRegistry.getAccessType({ account: users.alice })), uint256(newAccessType), "AccessType");

        oldAccessType = kycRegistry.getAccessType(users.alice);
        newAccessType = KYCRegistry.AccessType.UNRESTRICTED;

        vm.expectEmit({
            checkTopic1: true,
            checkTopic2: true,
            checkTopic3: true,
            checkData: true,
            emitter: address(kycRegistry)
        });
        emit AccessTypeModified({
            admin: users.admin,
            account: users.alice,
            oldAccessType: oldAccessType,
            newAccessType: newAccessType
        });
        kycRegistry.modifyAccessType({ account: users.alice, newAccessType: newAccessType });
        assertEq(uint256(kycRegistry.getAccessType({ account: users.alice })), uint256(newAccessType), "AccessType");
    }

    function testCannot_ModifyAccessType_Unauthorized() public {
        hoax(users.eve, users.eve);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        kycRegistry.modifyAccessType({ account: users.eve, newAccessType: KYCRegistry.AccessType.UNRESTRICTED });
    }

    /* `setSignerModule()` Tests */

    function test_SetSignerModule_Fuzzed(SegMintSignerModule newSignerModule) public {
        hoax(users.admin, users.admin);
        kycRegistry.setSignerModule({ newSignerModule: newSignerModule });
        assertEq(address(kycRegistry.signerModule()), address(newSignerModule));
    }

    function testCannot_SetSignerModule_Unauthorized() public {
        hoax(users.eve, users.eve);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        kycRegistry.setSignerModule({ newSignerModule: SegMintSignerModule(users.eve) });
    }
}
