// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./BaseTest.sol";

contract SignerRegistryTest is BaseTest {
    // function setUp() public override {
    //     super.setUp();
    // }

    // function test_SignerRegistry_Deployment() public {
    //     assertEq(signerRegistry.owner(), address(this));
    //     assertEq(signerRegistry.getSigner(), signer);
    //     assertTrue(signerRegistry.hasAllRoles({ user: users.admin, roles: ADMIN_ROLE }));
    // }

    // function test_SetSigner(address account) public {
    //     address initialSigner = signerRegistry.getSigner();

    //     hoax(users.admin, users.admin);
    //     vm.expectEmit({
    //         checkTopic1: true,
    //         checkTopic2: true,
    //         checkTopic3: true,
    //         checkData: true,
    //         emitter: address(signerRegistry)
    //     });
    //     emit SignerUpdated({ admin: users.admin, oldSigner: initialSigner, newSigner: account });
    //     signerRegistry.setSigner({ newSigner: account });

    //     address updatedSigner = signerRegistry.getSigner();
    //     assertEq(updatedSigner, account);
    // }

    // function testCannot_SetSigner_Unauthorized() public {
    //     hoax(users.eve, users.eve);
    //     vm.expectRevert(UNAUTHORIZED_SELECTOR);
    //     signerRegistry.setSigner({ newSigner: users.eve });
    // }
}
