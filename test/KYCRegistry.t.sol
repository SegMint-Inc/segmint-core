// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./BaseTest.sol";

contract KYCRegistryTest is BaseTest {
    // function setUp() public override {
    //     super.setUp();
    // }

    // function test_KYCRegistry_Deployment() public {
    //     assertEq(kycRegistry.owner(), address(this));
    //     assertEq(address(kycRegistry.signerRegistry()), address(signerRegistry));
    //     assertTrue(kycRegistry.hasAllRoles({ user: users.admin, roles: ADMIN_ROLE }));
    // }

    // function test_InitAccessType() public {
    //     uint256 deadline = block.timestamp + 1 hours;
    //     IKYCRegistry.AccessType accessType = IKYCRegistry.AccessType.RESTRICTED;

    //     startHoax(users.alice, users.alice);
    //     vm.expectEmit({
    //         checkTopic1: true,
    //         checkTopic2: true,
    //         checkTopic3: false,
    //         checkData: true,
    //         emitter: address(kycRegistry)
    //     });
    //     emit AccessTypeSet({ account: users.alice, accessType: accessType });
    //     kycRegistry.initAccessType({
    //         signature: getAccessSignature(users.alice, deadline, accessType),
    //         deadline: deadline,
    //         newAccessType: accessType
    //     });

    //     assertEq(uint256(kycRegistry.accessType({ account: users.alice })), uint256(accessType));
    // }

    // function testCannot_InitAccessType_DeadlinePassed() public {
    //     uint256 deadline = block.timestamp;
    //     IKYCRegistry.AccessType accessType = IKYCRegistry.AccessType.RESTRICTED;

    //     vm.warp(deadline + 1 seconds);

    //     startHoax(users.alice, users.alice);
    //     vm.expectRevert(IKYCRegistry.DeadlinePassed.selector);
    //     kycRegistry.initAccessType({
    //         signature: getAccessSignature(users.alice, deadline, accessType),
    //         deadline: deadline,
    //         newAccessType: accessType
    //     });
    // }

    // function testCannot_InitAccessType_AccessTypeDefined() public {
    //     uint256 deadline = block.timestamp + 1 hours;
    //     IKYCRegistry.AccessType accessType = IKYCRegistry.AccessType.RESTRICTED;
    //     bytes memory signature = getAccessSignature(users.alice, deadline, accessType);

    //     startHoax(users.alice, users.alice);
    //     kycRegistry.initAccessType({ signature: signature, deadline: deadline, newAccessType: accessType });
    //     vm.expectRevert(IKYCRegistry.AccessTypeDefined.selector);
    //     kycRegistry.initAccessType({ signature: signature, deadline: deadline, newAccessType: accessType });
    // }

    // function testCannot_InitAccessType_InvalidAccessType() public {
    //     uint256 deadline = block.timestamp + 1 hours;
    //     IKYCRegistry.AccessType accessType = IKYCRegistry.AccessType.BLOCKED;

    //     startHoax(users.alice, users.alice);
    //     vm.expectRevert(IKYCRegistry.InvalidAccessType.selector);
    //     kycRegistry.initAccessType({
    //         signature: getAccessSignature(users.alice, deadline, accessType),
    //         deadline: deadline,
    //         newAccessType: accessType
    //     });
    // }

    // function testCannot_InitAccessType_SignerMismatch() public {
    //     uint256 deadline = block.timestamp + 1 hours;
    //     IKYCRegistry.AccessType accessType = IKYCRegistry.AccessType.RESTRICTED;

    //     startHoax(users.alice, users.alice);
    //     vm.expectRevert(ISignerRegistry.SignerMismatch.selector);
    //     kycRegistry.initAccessType({
    //         signature: getAccessSignature(users.alice, deadline, accessType),
    //         deadline: deadline,
    //         newAccessType: IKYCRegistry.AccessType.UNRESTRICTED
    //     });
    // }

    // function test_ModifyAccessType() public {
    //     IKYCRegistry.AccessType accessType = IKYCRegistry.AccessType.RESTRICTED;

    //     hoax(users.admin, users.admin);
    //     vm.expectEmit({
    //         checkTopic1: true,
    //         checkTopic2: true,
    //         checkTopic3: true,
    //         checkData: true,
    //         emitter: address(kycRegistry)
    //     });
    //     emit AccessTypeModified({
    //         admin: users.admin,
    //         account: users.alice,
    //         oldAccessType: IKYCRegistry.AccessType.BLOCKED,
    //         newAccessType: accessType
    //     });
    //     kycRegistry.modifyAccessType({ account: users.alice, newAccessType: accessType });
    // }

    // function testCannot_ModifyAccessType_Unauthorized() public {
    //     hoax(users.eve, users.eve);
    //     vm.expectRevert(UNAUTHORIZED_SELECTOR);
    //     kycRegistry.modifyAccessType({ account: users.eve, newAccessType: IKYCRegistry.AccessType.UNRESTRICTED });
    // }

    // function test_SetSignerRegistry(ISignerRegistry newSignerRegistry) public {
    //     hoax(users.admin, users.admin);
    //     kycRegistry.setSignerRegistry(newSignerRegistry);
    //     assertEq(address(kycRegistry.signerRegistry()), address(newSignerRegistry));
    // }

    // function testCannot_SetSignerRegistry_Unauthorized() public {
    //     hoax(users.eve, users.eve);
    //     vm.expectRevert(UNAUTHORIZED_SELECTOR);
    //     kycRegistry.setSignerRegistry(ISignerRegistry(users.eve));
    // }
}
