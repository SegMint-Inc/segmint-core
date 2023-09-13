// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./BaseTest.sol";

contract AccessRegistryTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_AccessRegistry_Deployment() public {
        address owner = accessRegistry.owner();
        assertEq(owner, address(this));

        ISignerRegistry actualSignerRegistry = accessRegistry.signerRegistry();
        assertEq(actualSignerRegistry, signerRegistry);

        bool result = accessRegistry.hasAllRoles({ user: users.admin, roles: signerRegistry.ADMIN_ROLE() });
        assertTrue(result);
    }

    function test_InitAccessType() public {
        uint256 deadline = block.timestamp + 1 hours;
        IAccessRegistry.AccessType accessType = IAccessRegistry.AccessType.RESTRICTED;
        bytes memory signature = getAccessSignature(users.alice.account, deadline, accessType);

        hoax(users.alice.account);
        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: true });
        emit AccessTypeSet({ account: users.alice.account, accessType: accessType, signature: signature });
        accessRegistry.initAccessType({ signature: signature, deadline: deadline, newAccessType: accessType });

        assertEq(accessRegistry.accessType({ account: users.alice.account }), accessType);
    }

    function testCannot_InitAccessType_DeadlinePassed() public {
        uint256 deadline = block.timestamp;
        IAccessRegistry.AccessType accessType = IAccessRegistry.AccessType.RESTRICTED;
        bytes memory signature = getAccessSignature(users.alice.account, deadline, accessType);

        vm.warp(deadline + 1 seconds);

        hoax(users.alice.account);
        vm.expectRevert(IAccessRegistry.DeadlinePassed.selector);
        accessRegistry.initAccessType({ signature: signature, deadline: deadline, newAccessType: accessType });
    }

    function testCannot_InitAccessType_AccessTypeDefined() public {
        uint256 deadline = block.timestamp + 1 hours;
        IAccessRegistry.AccessType accessType = IAccessRegistry.AccessType.RESTRICTED;
        bytes memory signature = getAccessSignature(users.alice.account, deadline, accessType);

        startHoax(users.alice.account);
        accessRegistry.initAccessType({ signature: signature, deadline: deadline, newAccessType: accessType });
        vm.expectRevert(IAccessRegistry.AccessTypeDefined.selector);
        accessRegistry.initAccessType({ signature: signature, deadline: deadline, newAccessType: accessType });
    }

    function testCannot_InitAccessType_InvalidAccessType() public {
        uint256 deadline = block.timestamp;
        IAccessRegistry.AccessType accessType = IAccessRegistry.AccessType.BLOCKED;
        bytes memory signature = getAccessSignature(users.alice.account, deadline, accessType);

        hoax(users.alice.account);
        vm.expectRevert(IAccessRegistry.InvalidAccessType.selector);
        accessRegistry.initAccessType({ signature: signature, deadline: deadline, newAccessType: accessType });
    }

    function testCannot_InitAccessType_SignerMismatch() public {
        uint256 deadline = block.timestamp + 1 hours;
        IAccessRegistry.AccessType accessType = IAccessRegistry.AccessType.RESTRICTED;
        bytes memory signature = getAccessSignature(users.alice.account, deadline, accessType);

        hoax(users.alice.account);
        vm.expectRevert(ISignerRegistry.SignerMismatch.selector);
        accessRegistry.initAccessType({
            signature: signature,
            deadline: deadline,
            newAccessType: IAccessRegistry.AccessType.UNRESTRICTED
        });
    }

    function test_ModifyAccessType() public {
        IAccessRegistry.AccessType accessType = IAccessRegistry.AccessType.RESTRICTED;

        hoax(users.admin);
        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: true });
        emit AccessTypeModified({
            admin: users.admin,
            account: users.alice.account,
            oldAccessType: IAccessRegistry.AccessType.BLOCKED,
            newAccessType: accessType
        });
        accessRegistry.modifyAccessType({ account: users.alice.account, newAccessType: accessType });
    }

    function testCannot_ModifyAccessType_Unauthorized_Fuzzed(address nonAdmin) public {
        vm.assume(nonAdmin != users.admin);

        hoax(nonAdmin);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        accessRegistry.modifyAccessType({ account: nonAdmin, newAccessType: IAccessRegistry.AccessType.UNRESTRICTED });
    }

    function test_SetSignerRegistry_Fuzzed(ISignerRegistry newSignerRegistry) public {
        hoax(users.admin);
        accessRegistry.setSignerRegistry(newSignerRegistry);
        assertEq(accessRegistry.signerRegistry(), newSignerRegistry);
    }

    function testCannot_SetSignerRegistry_Unauthorized_Fuzzed(address nonAdmin, ISignerRegistry badRegistry) public {
        vm.assume(nonAdmin != users.admin);

        hoax(nonAdmin);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        accessRegistry.setSignerRegistry(badRegistry);
    }
}
