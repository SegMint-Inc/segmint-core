// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../Base.t.sol";

contract SegMintKYCRegistryTest is Base {
    using ECDSA for bytes32;

    function setUp() public override {
        super.setUp();
    }

    /* Deployment Test */

    function test_SegMintKYCRegistry_Deployment() public {
        assertTrue(kycRegistry.hasAllRoles(users.admin, ADMIN_ROLE));
        assertEq(kycRegistry.owner(), address(this));
        assertEq(kycRegistry.signer(), SIGNER);
    }

    /* `setAccessType()` Tests */

    function test_SetAccessType_Restricted() public {
        ISegMintKYCRegistry.AccessType accessType = ISegMintKYCRegistry.AccessType.RESTRICTED;
        bytes memory signature = getAccessSignature(users.alice, accessType);

        hoax(users.alice, users.alice);
        vm.expectEmit();
        emit AccessTypeSet({account: users.alice, accessType: accessType});
        kycRegistry.setAccessType({signature: signature, newAccessType: accessType});

        assertEq(uint256(kycRegistry.getAccessType({account: users.alice})), uint256(accessType), "AccessType");
    }

    function test_SetAccessType_Unrestricted() public {
        ISegMintKYCRegistry.AccessType accessType = ISegMintKYCRegistry.AccessType.UNRESTRICTED;
        bytes memory signature = getAccessSignature(users.bob, accessType);

        hoax(users.bob, users.bob);
        vm.expectEmit();
        emit AccessTypeSet({account: users.bob, accessType: accessType});
        kycRegistry.setAccessType({signature: signature, newAccessType: accessType});

        assertEq(uint256(kycRegistry.getAccessType({account: users.bob})), uint256(accessType), "AccessType");
    }

    function test_SetAccessType_Fuzzed(address account) public {
        ISegMintKYCRegistry.AccessType accessType = uint160(account) & 1 == 0 ?
            ISegMintKYCRegistry.AccessType.RESTRICTED :
            ISegMintKYCRegistry.AccessType.UNRESTRICTED;

        bytes memory signature = getAccessSignature(account, accessType);

        hoax(account, account);
        vm.expectEmit();
        emit AccessTypeSet({account: account, accessType: accessType});
        kycRegistry.setAccessType({signature: signature, newAccessType: accessType});

        assertEq(uint256(kycRegistry.getAccessType({account: account})), uint256(accessType), "AccessType");
    }

    function testCannot_SetAccessType_AccessTypeSet() public {
        ISegMintKYCRegistry.AccessType accessType = ISegMintKYCRegistry.AccessType.RESTRICTED;
        bytes memory signature = getAccessSignature(users.alice, accessType);

        startHoax(users.alice, users.alice);
        kycRegistry.setAccessType({signature: signature, newAccessType: accessType});
        vm.expectRevert(Errors.AccessTypeSet.selector);
        kycRegistry.setAccessType({signature: signature, newAccessType: accessType});
    }

    function testCannot_SetAccessType_NoneAccessType() public {
        ISegMintKYCRegistry.AccessType accessType = ISegMintKYCRegistry.AccessType.NONE;
        bytes memory signature = getAccessSignature(users.alice, accessType);

        hoax(users.alice, users.alice);
        vm.expectRevert(Errors.NoneAccessType.selector);
        kycRegistry.setAccessType({signature: signature, newAccessType: accessType});
    }

    function testCannot_SetAccessType_SignerMismatch() public {
        hoax(users.admin, users.admin);
        kycRegistry.setSigner(address(0));

        ISegMintKYCRegistry.AccessType accessType = ISegMintKYCRegistry.AccessType.RESTRICTED;
        bytes memory signature = getAccessSignature(users.alice, accessType);

        hoax(users.alice, users.alice);
        vm.expectRevert(Errors.SignerMismatch.selector);
        kycRegistry.setAccessType({signature: signature, newAccessType: accessType});
    }

    /* `modifyAccessType()` Tests */

    function test_ModifyAccessType() public {
        ISegMintKYCRegistry.AccessType accessType = ISegMintKYCRegistry.AccessType.RESTRICTED;

        startHoax(users.admin, users.admin);
        vm.expectEmit();
        emit AccessTypeModified({admin: users.admin, account: users.alice, accessType: accessType});
        kycRegistry.modifyAccessType({account: users.alice, newAccessType: accessType});
        assertEq(uint256(kycRegistry.getAccessType({account: users.alice})), uint256(accessType), "AccessType");

        accessType = ISegMintKYCRegistry.AccessType.UNRESTRICTED;

        vm.expectEmit();
        emit AccessTypeModified({admin: users.admin, account: users.bob, accessType: accessType});
        kycRegistry.modifyAccessType({account: users.bob, newAccessType: accessType});
        assertEq(uint256(kycRegistry.getAccessType({account: users.bob})), uint256(accessType), "AccessType");
    }

    function testCannot_ModifyAccessType_Unauthorized() public {
        hoax(users.eve, users.eve);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        kycRegistry.modifyAccessType({account: users.eve, newAccessType: ISegMintKYCRegistry.AccessType.UNRESTRICTED});
    }

    /* `setSigner()` Tests */

    function test_SetSigner_Fuzzed(address newSigner) public {
        hoax(users.admin, users.admin);
        kycRegistry.setSigner({newSigner: newSigner});
        assertEq(kycRegistry.signer(), newSigner);
    }

    function testCannot_SetSigner_Unauthorized() public {
        hoax(users.eve, users.eve);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        kycRegistry.setSigner({newSigner: users.eve});
    }

    /* Helper Functions */

    function getAccessSignature(address account, ISegMintKYCRegistry.AccessType accessType)
        internal
        pure
        returns (bytes memory)
    {
        bytes32 digest = keccak256(abi.encodePacked(account, accessType)).toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PRIVATE_KEY, digest);
        return abi.encodePacked(r, s, v);
    }
}
