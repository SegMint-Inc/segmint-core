// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../Base.t.sol";

contract SegMintSignerModuleTest is Base {
    function setUp() public override {
        super.setUp();
    }

    /* Deployment Test */

    function test_SegMintSignerModule_Deployment() public {
        assertEq(signerModule.getSigner(), SIGNER);
    }

    /* `setSigner()` Tests */

    function test_SetSigner_Fuzzed(address newSigner) public {
        vm.assume(newSigner != address(0));
        address oldSigner = signerModule.getSigner();

        hoax(users.admin, users.admin);
        vm.expectEmit({
            checkTopic1: true,
            checkTopic2: true,
            checkTopic3: true,
            checkData: true,
            emitter: address(signerModule)
        });
        emit SignerUpdated({ admin: users.admin, oldSigner: oldSigner, newSigner: newSigner });
        signerModule.setSigner(newSigner);

        assertEq(signerModule.getSigner(), newSigner);
    }

    function testCannot_SetSigner_Unauthorized() public {
        hoax(users.eve, users.eve);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        signerModule.setSigner(users.eve);
    }
}
