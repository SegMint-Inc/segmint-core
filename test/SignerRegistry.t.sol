// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./BaseTest.sol";

contract SignerRegistryTest is BaseTest {
    function setUp() public override {
        super.setUp();
    }

    function test_SignerRegistry_Deployment() public {
        address owner = signerRegistry.owner();
        assertEq(owner, address(this));

        address signer = signerRegistry.getSigner();
        assertEq(signer, users.signer.account);

        bool result = signerRegistry.hasAllRoles({ user: users.admin, roles: signerRegistry.ADMIN_ROLE() });
        assertTrue(result);
    }

    function test_SetSigner_Fuzzed(address signer) public {
        address initialSigner = signerRegistry.getSigner();

        hoax(users.admin);
        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: true });
        emit SignerUpdated({ admin: users.admin, oldSigner: initialSigner, newSigner: signer });
        signerRegistry.setSigner({ newSigner: signer });

        assertEq(signerRegistry.getSigner(), signer);
    }

    function testCannot_SetSigner_Unauthorized_Fuzzed(address nonAdmin) public {
        vm.assume(nonAdmin != users.admin);

        hoax(nonAdmin);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        signerRegistry.setSigner({ newSigner: nonAdmin });
    }
}
