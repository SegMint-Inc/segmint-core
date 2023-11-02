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

    function testCannotDeploy_Admin_ZeroAddressInvalid() public {
        vm.expectRevert(IAccessRegistry.ZeroAddressInvalid.selector);
        new AccessRegistry({ admin_: address(0), signerRegistry_: signerRegistry });
    }

    function testCannotDeploy_SignerRegistry_ZeroAddressInvalid() public {
        vm.expectRevert(IAccessRegistry.ZeroAddressInvalid.selector);
        new AccessRegistry({ admin_: users.admin, signerRegistry_: ISignerRegistry(address(0)) });
    }

    function test_InitAccessType() public {
        uint256 deadline = block.timestamp + 1 hours;
        IAccessRegistry.AccessType accessType = IAccessRegistry.AccessType.RESTRICTED;

        IAccessRegistry.AccessParams memory accessParams = IAccessRegistry.AccessParams({
            user: users.alice.account,
            deadline: deadline,
            nonce: accessRegistry.accountNonce(users.alice.account),
            accessType: accessType
        });
        bytes memory signature = getAccessSignature(accessParams);

        hoax(users.alice.account);
        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: true });
        emit AccessTypeSet({ account: users.alice.account, accessType: accessType, signature: signature });
        accessRegistry.initAccessType(accessParams, signature);

        assertEq(accessRegistry.accessType({ account: users.alice.account }), accessType);
        assertEq(accessRegistry.accountNonce({ account: users.alice.account }), 1);
    }

    function testCannot_InitAccessType_DeadlinePassed() public {
        IAccessRegistry.AccessParams memory accessParams = IAccessRegistry.AccessParams({
            user: users.alice.account,
            deadline: block.timestamp,
            nonce: accessRegistry.accountNonce(users.alice.account),
            accessType: IAccessRegistry.AccessType.RESTRICTED
        });
        bytes memory signature = getAccessSignature(accessParams);

        vm.warp(accessParams.deadline + 1 seconds);

        hoax(users.alice.account);
        vm.expectRevert(IAccessRegistry.DeadlinePassed.selector);
        accessRegistry.initAccessType(accessParams, signature);
    }

    function testCannot_InitAccessType_AccessTypeDefined() public {
        IAccessRegistry.AccessParams memory accessParams = IAccessRegistry.AccessParams({
            user: users.alice.account,
            deadline: block.timestamp,
            nonce: accessRegistry.accountNonce(users.alice.account),
            accessType: IAccessRegistry.AccessType.RESTRICTED
        });
        bytes memory signature = getAccessSignature(accessParams);

        startHoax(users.alice.account);
        accessRegistry.initAccessType(accessParams, signature);

        vm.expectRevert(IAccessRegistry.AccessTypeDefined.selector);
        accessRegistry.initAccessType(accessParams, signature);
    }

    function testCannot_InitAccessType_UserAddressMismatch() public {
        IAccessRegistry.AccessType accessType = IAccessRegistry.AccessType.RESTRICTED;
        IAccessRegistry.AccessParams memory accessParams = IAccessRegistry.AccessParams({
            user: users.alice.account,
            deadline: block.timestamp,
            nonce: accessRegistry.accountNonce(users.alice.account),
            accessType: accessType
        });
        bytes memory signature = getAccessSignature(accessParams);

        hoax(users.bob.account);
        vm.expectRevert(IAccessRegistry.UserAddressMismatch.selector);
        accessRegistry.initAccessType(accessParams, signature);
    }

    function testCannot_InitAccessType_InvalidAccessType() public {
        IAccessRegistry.AccessParams memory accessParams = IAccessRegistry.AccessParams({
            user: users.alice.account,
            deadline: block.timestamp,
            nonce: accessRegistry.accountNonce(users.alice.account),
            accessType: IAccessRegistry.AccessType.BLOCKED
        });
        bytes memory signature = getAccessSignature(accessParams);

        hoax(users.alice.account);
        vm.expectRevert(IAccessRegistry.InvalidAccessType.selector);
        accessRegistry.initAccessType(accessParams, signature);
    }

    function testCannot_InitAccessType_NonceUsed() public {
        IAccessRegistry.AccessParams memory accessParams = IAccessRegistry.AccessParams({
            user: users.alice.account,
            deadline: block.timestamp,
            nonce: accessRegistry.accountNonce(users.alice.account),
            accessType: IAccessRegistry.AccessType.RESTRICTED
        });
        bytes memory signature = getAccessSignature(accessParams);

        hoax(users.alice.account);
        accessRegistry.initAccessType(accessParams, signature);

        hoax(users.admin);
        accessRegistry.modifyAccessType({
            account: users.alice.account,
            newAccessType: IAccessRegistry.AccessType.BLOCKED
        });

        hoax(users.alice.account);
        vm.expectRevert(IAccessRegistry.NonceUsed.selector);
        accessRegistry.initAccessType(accessParams, signature);
        
    }

    function testCannot_InitAccessType_SignerMismatch() public {
        IAccessRegistry.AccessParams memory accessParams = IAccessRegistry.AccessParams({
            user: users.alice.account,
            deadline: block.timestamp,
            nonce: accessRegistry.accountNonce(users.alice.account),
            accessType: IAccessRegistry.AccessType.RESTRICTED
        });
        bytes memory signature = getAccessSignature(accessParams);
        accessParams.accessType = IAccessRegistry.AccessType.UNRESTRICTED;


        hoax(users.alice.account);
        vm.expectRevert(ISignerRegistry.SignerMismatch.selector);
        accessRegistry.initAccessType(accessParams, signature);
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
        vm.assume(address(newSignerRegistry) != address(0));
        ISignerRegistry oldSignerRegistry = accessRegistry.signerRegistry();

        hoax(users.admin);
        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: false, checkData: true });
        emit SignerRegistryUpdated({ oldSignerRegistry: oldSignerRegistry, newSignerRegistry: newSignerRegistry });
        accessRegistry.setSignerRegistry(newSignerRegistry);

        assertEq(accessRegistry.signerRegistry(), newSignerRegistry);
    }

    function testCannot_SetSignerRegistry_Unauthorized_Fuzzed(address nonAdmin, ISignerRegistry badRegistry) public {
        vm.assume(nonAdmin != users.admin);

        hoax(nonAdmin);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        accessRegistry.setSignerRegistry(badRegistry);
    }

    function testCannot_SetSignerRegistry_ZeroAddressInvalid() public {
        hoax(users.admin);
        vm.expectRevert(ISignerRegistry.ZeroAddressInvalid.selector);
        accessRegistry.setSignerRegistry({ newSignerRegistry: ISignerRegistry(address(0)) });
    }
}
