// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./BaseTest.sol";

contract KYCRegistryTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_KYCRegistry_Deployment() public {
        address owner = kycRegistry.owner();
        assertEq(owner, address(this));

        ISignerRegistry actualSignerRegistry = kycRegistry.signerRegistry();
        assertEq(actualSignerRegistry, signerRegistry);

        bool result = kycRegistry.hasAllRoles({ user: users.admin, roles: signerRegistry.ADMIN_ROLE() });
        assertTrue(result);
    }

    function test_InitAccessType() public {
        uint256 deadline = block.timestamp + 1 hours;
        IKYCRegistry.AccessType accessType = IKYCRegistry.AccessType.RESTRICTED;
        bytes memory signature = getAccessSignature(users.alice.account, deadline, accessType);

        hoax(users.alice.account);
        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: true });
        emit AccessTypeSet({ account: users.alice.account, accessType: accessType, signature: signature });
        kycRegistry.initAccessType({ signature: signature, deadline: deadline, newAccessType: accessType });

        assertEq(kycRegistry.accessType({ account: users.alice.account }), accessType);
    }

    function testCannot_InitAccessType_DeadlinePassed() public {
        uint256 deadline = block.timestamp;
        IKYCRegistry.AccessType accessType = IKYCRegistry.AccessType.RESTRICTED;
        bytes memory signature = getAccessSignature(users.alice.account, deadline, accessType);

        vm.warp(deadline + 1 seconds);

        hoax(users.alice.account);
        vm.expectRevert(IKYCRegistry.DeadlinePassed.selector);
        kycRegistry.initAccessType({ signature: signature, deadline: deadline, newAccessType: accessType });
    }

    function testCannot_InitAccessType_AccessTypeDefined() public {
        uint256 deadline = block.timestamp + 1 hours;
        IKYCRegistry.AccessType accessType = IKYCRegistry.AccessType.RESTRICTED;
        bytes memory signature = getAccessSignature(users.alice.account, deadline, accessType);

        startHoax(users.alice.account);
        kycRegistry.initAccessType({ signature: signature, deadline: deadline, newAccessType: accessType });
        vm.expectRevert(IKYCRegistry.AccessTypeDefined.selector);
        kycRegistry.initAccessType({ signature: signature, deadline: deadline, newAccessType: accessType });
    }

    function testCannot_InitAccessType_InvalidAccessType() public {
        uint256 deadline = block.timestamp;
        IKYCRegistry.AccessType accessType = IKYCRegistry.AccessType.BLOCKED;
        bytes memory signature = getAccessSignature(users.alice.account, deadline, accessType);

        hoax(users.alice.account);
        vm.expectRevert(IKYCRegistry.InvalidAccessType.selector);
        kycRegistry.initAccessType({ signature: signature, deadline: deadline, newAccessType: accessType });
    }

    function testCannot_InitAccessType_SignerMismatch() public {
        uint256 deadline = block.timestamp + 1 hours;
        IKYCRegistry.AccessType accessType = IKYCRegistry.AccessType.RESTRICTED;
        bytes memory signature = getAccessSignature(users.alice.account, deadline, accessType);

        hoax(users.alice.account);
        vm.expectRevert(ISignerRegistry.SignerMismatch.selector);
        kycRegistry.initAccessType({
            signature: signature,
            deadline: deadline,
            newAccessType: IKYCRegistry.AccessType.UNRESTRICTED
        });
    }

    function test_ModifyAccessType() public {
        IKYCRegistry.AccessType accessType = IKYCRegistry.AccessType.RESTRICTED;

        hoax(users.admin);
        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: true });
        emit AccessTypeModified({
            admin: users.admin,
            account: users.alice.account,
            oldAccessType: IKYCRegistry.AccessType.BLOCKED,
            newAccessType: accessType
        });
        kycRegistry.modifyAccessType({ account: users.alice.account, newAccessType: accessType });
    }

    function testCannot_ModifyAccessType_Unauthorized_Fuzzed(address nonAdmin) public {
        vm.assume(nonAdmin != users.admin);

        hoax(nonAdmin);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        kycRegistry.modifyAccessType({ account: nonAdmin, newAccessType: IKYCRegistry.AccessType.UNRESTRICTED });
    }

    function test_SetSignerRegistry_Fuzzed(ISignerRegistry newSignerRegistry) public {
        hoax(users.admin);
        kycRegistry.setSignerRegistry(newSignerRegistry);
        assertEq(kycRegistry.signerRegistry(), newSignerRegistry);
    }

    function testCannot_SetSignerRegistry_Unauthorized_Fuzzed(address nonAdmin, ISignerRegistry badRegistry) public {
        vm.assume(nonAdmin != users.admin);

        hoax(nonAdmin);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        kycRegistry.setSignerRegistry(badRegistry);
    }
}
