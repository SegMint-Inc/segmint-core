// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../Base.t.sol";

contract SignerManagerTest is Base {
    modifier setUpSigners() {
        address[] memory signers = getSignersArray();
        signerManager.initializeSigners({ signers: signers, quorumValue: uint96(signers.length) });
        _;
    }

    function setUp() public override {
        super.setUp();
    }

    /* Deployment Test */

    function test_SignerManager_Deployment() public {
        assertEq(signerManager.quorum(), 0);
    }

    /* `initializeSigners()` Tests */

    function test_InitializeSigners() public {
        address[] memory signers = getSignersArray();
        signerManager.initializeSigners({ signers: signers, quorumValue: uint96(signers.length) });
        assertEq(signerManager.quorum(), signers.length);
        assertEq(signerManager.signerCount(), signers.length);

        address[] memory initialSigners = signerManager.getSigners();
        assertEq(initialSigners.length, signers.length);

        for (uint256 i = 0; i < signers.length; i++) {
            address account = initialSigners[i];
            assertEq(account, signers[i]);
            assertTrue(signerManager.isSigner(account));
        }

        address lastSigner = initialSigners[signers.length - 1];
        assertEq(signerManager.approvedSigners(lastSigner), signerManager.sentinelValue());
    }

    function testCannot_InitializeSigners_InvalidSigner_ZeroAddress() public {
        address[] memory signers = getSignersArray();
        signers[0] = address(0);

        vm.expectRevert(Errors.InvalidSigner.selector);
        signerManager.initializeSigners({ signers: signers, quorumValue: uint96(signers.length) });
    }

    function testCannot_InitializeSigners_InvalidSigner_SentinelValue() public {
        address[] memory signers = getSignersArray();
        signers[0] = signerManager.sentinelValue();

        vm.expectRevert(Errors.InvalidSigner.selector);
        signerManager.initializeSigners({ signers: signers, quorumValue: uint96(signers.length) });
    }

    function testCannot_InitializeSigners_InvalidSigner_Self() public {
        address[] memory signers = getSignersArray();
        signers[0] = address(signerManager);

        vm.expectRevert(Errors.InvalidSigner.selector);
        signerManager.initializeSigners({ signers: signers, quorumValue: uint96(signers.length) });
    }

    function testCannot_InitializeSigners_InvalidSigner_Concurrent() public {
        address[] memory signers = getSignersArray();
        signers[1] = signers[0]; // [alice, bob, babe, cafe] -> [alice, alice, babe, cafe]

        vm.expectRevert(Errors.InvalidSigner.selector);
        signerManager.initializeSigners({ signers: signers, quorumValue: uint96(signers.length) });
    }

    function testCannot_InitializeSigners_InvalidSigner_Duplicate() public {
        address[] memory signers = getSignersArray();
        signers[2] = signers[0]; // [alice, bob, babe, cafe] -> [alice, bob, alice, cafe]

        vm.expectRevert(Errors.DuplicateSigner.selector);
        signerManager.initializeSigners({ signers: signers, quorumValue: uint96(signers.length) });
    }

    /* `removeSigner()` Tests */

    function test_RemoveSigner() public setUpSigners {
        address[] memory signers = signerManager.getSigners();

        uint256 newQuorum = signers.length - 1;
        address alice = signers[0];
        address sentinelValue = signerManager.sentinelValue();

        hoax(address(signerManager));
        signerManager.removeSigner({ ptrSigner: sentinelValue, signer: alice, quorumValue: newQuorum });
        assertEq(signerManager.quorum(), newQuorum);

        address[] memory newSigners = signerManager.getSigners();
        assertEq(newSigners.length, signers.length - 1);
        assertEq(signerManager.signerCount(), signers.length - 1);

        for (uint256 i = 0; i < newSigners.length; i++) {
            assertTrue(newSigners[i] != alice);
        }

        assertEq(signerManager.approvedSigners(alice), address(0));
        assertEq(signerManager.approvedSigners(sentinelValue), newSigners[0]);
    }

    function testCannot_RemoveSigner_RemovalBreaksQuorum() public setUpSigners {
        address[] memory signers = signerManager.getSigners();
        address sentinelValue = signerManager.sentinelValue();

        hoax(address(signerManager));
        vm.expectRevert(Errors.RemovalBreaksQuorum.selector);
        signerManager.removeSigner({ ptrSigner: sentinelValue, signer: signers[0], quorumValue: signers.length });
    }

    function testCannot_RemoveSigner_InvalidSigner_ZeroAddress() public setUpSigners {
        address sentinelValue = signerManager.sentinelValue();

        hoax(address(signerManager));
        vm.expectRevert(Errors.InvalidSigner.selector);
        signerManager.removeSigner({ ptrSigner: sentinelValue, signer: address(0), quorumValue: 1 });
    }

    function testCannot_RemoveSigner_InvalidSigner_SentinelValue() public setUpSigners {
        address sentinelValue = signerManager.sentinelValue();

        hoax(address(signerManager));
        vm.expectRevert(Errors.InvalidSigner.selector);
        signerManager.removeSigner({ ptrSigner: sentinelValue, signer: sentinelValue, quorumValue: 1 });
    }

    function testCannot_RemoveSigner_InvalidPointer() public setUpSigners {
        address[] memory signers = signerManager.getSigners();
        address sentinelValue = signerManager.sentinelValue();

        hoax(address(signerManager));
        vm.expectRevert(Errors.InvalidPointer.selector);
        signerManager.removeSigner({ ptrSigner: sentinelValue, signer: signers[1], quorumValue: 3 });
    }

    /* `addSigner()` Tests */

    function test_AddSigner() public setUpSigners {
        address[] memory signers = signerManager.getSigners();
        uint256 newQuorum = signers.length + 1;
        address newSigner = address(0xbeef);

        hoax(address(signerManager));
        signerManager.addSigner({ newSigner: newSigner, quorumValue: newQuorum });

        assertEq(signerManager.quorum(), newQuorum);

        address[] memory newSigners = signerManager.getSigners();
        assertEq(newSigners.length, signers.length + 1);
        assertEq(signerManager.signerCount(), signers.length + 1);

        address sentinelValue = signerManager.sentinelValue();
        assertEq(signerManager.approvedSigners(sentinelValue), newSigner);
    }

    function testCannot_AddSigner_InvalidSigner_ZeroAddress() public setUpSigners {
        hoax(address(signerManager));
        vm.expectRevert(Errors.InvalidSigner.selector);
        signerManager.addSigner({ newSigner: address(0), quorumValue: 1 });
    }

    function testCannot_AddSigner_InvalidSigner_SentinelValue() public setUpSigners {
        address sentinelValue = signerManager.sentinelValue();

        hoax(address(signerManager));
        vm.expectRevert(Errors.InvalidSigner.selector);
        signerManager.addSigner({ newSigner: sentinelValue, quorumValue: 1 });
    }

    function testCannot_AddSigner_InvalidSigner_Self() public setUpSigners {
        hoax(address(signerManager));
        vm.expectRevert(Errors.InvalidSigner.selector);
        signerManager.addSigner({ newSigner: address(signerManager), quorumValue: 1 });
    }

    function testCannot_AddSigner_DuplicateSigner() public setUpSigners {
        address[] memory signers = signerManager.getSigners();

        hoax(address(signerManager));
        vm.expectRevert(Errors.DuplicateSigner.selector);
        signerManager.addSigner({ newSigner: signers[0], quorumValue: 1 });
    }

    /* `swapSigner()` Tests */

    function test_SwapSigner() public setUpSigners {
        address[] memory signers = signerManager.getSigners();

        address sentinelValue = signerManager.sentinelValue();
        address oldSigner = signers[0];
        address newSigner = address(0xbeef);

        hoax(address(signerManager));
        signerManager.swapSigner({ ptrSigner: sentinelValue, oldSigner: oldSigner, newSigner: newSigner });

        assertEq(signerManager.approvedSigners(sentinelValue), newSigner);
        assertEq(signerManager.approvedSigners(oldSigner), address(0));

        address[] memory newSigners = signerManager.getSigners();
        for (uint256 i = 0; i < newSigners.length; i++) {
            assertTrue(newSigners[i] != oldSigner);
        }
    }

    function testCannot_SwapSigner_InvalidCaller() public setUpSigners {
        address[] memory signers = signerManager.getSigners();
        address sentinelValue = signerManager.sentinelValue();

        vm.expectRevert(Errors.InvalidCaller.selector);
        signerManager.swapSigner({ ptrSigner: sentinelValue, oldSigner: signers[0], newSigner: address(0xbeef) });
    }

    function testCannot_SwapSigner_InvalidSigner_ZeroAddress() public setUpSigners {
        address[] memory signers = signerManager.getSigners();
        address sentinelValue = signerManager.sentinelValue();

        hoax(address(signerManager));
        vm.expectRevert(Errors.InvalidSigner.selector);
        signerManager.swapSigner({ ptrSigner: sentinelValue, oldSigner: signers[0], newSigner: address(0) });
    }

    function testCannot_SwapSigner_InvalidSigner_SentinelValue() public setUpSigners {
        address[] memory signers = signerManager.getSigners();
        address sentinelValue = signerManager.sentinelValue();

        hoax(address(signerManager));
        vm.expectRevert(Errors.InvalidSigner.selector);
        signerManager.swapSigner({ ptrSigner: signers[0], oldSigner: signers[1], newSigner: sentinelValue });
    }

    function testCannot_SwapSigner_InvalidSigner_Self() public setUpSigners {
        address[] memory signers = signerManager.getSigners();

        hoax(address(signerManager));
        vm.expectRevert(Errors.InvalidSigner.selector);
        signerManager.swapSigner({ ptrSigner: signers[0], oldSigner: signers[1], newSigner: address(signerManager) });
    }

    function testCannot_SwapSigner_DuplicateSigner() public setUpSigners {
        address[] memory signers = signerManager.getSigners();

        hoax(address(signerManager));
        vm.expectRevert(Errors.DuplicateSigner.selector);
        signerManager.swapSigner({ ptrSigner: signers[0], oldSigner: signers[1], newSigner: signers[3] });
    }

    function testCannot_SwapSigner_WRITE_TEST() public setUpSigners { }

    function testCannot_SwapSigner_PointerMismatch() public setUpSigners {
        address[] memory signers = signerManager.getSigners();

        hoax(address(signerManager));
        vm.expectRevert(Errors.PointerMismatch.selector);
        signerManager.swapSigner({ ptrSigner: signers[2], oldSigner: signers[0], newSigner: address(0xbeef) });
    }

    /* `updateQuorum()` Tests */

    function test_UpdateQuorum() public setUpSigners {
        address[] memory signers = signerManager.getSigners();
        uint256 newQuorum = signers.length - 1;

        hoax(address(signerManager));
        signerManager.updateQuorum({ quorumValue: newQuorum });

        assertEq(signerManager.quorum(), newQuorum);
    }

    function testCannot_UpdateQuorum_InvalidCaller() public setUpSigners {
        vm.expectRevert(Errors.InvalidCaller.selector);
        signerManager.updateQuorum({ quorumValue: 1 });
    }

    function testCannot_UpdateQuorum_InvalidQuorumValue_Zero() public setUpSigners {
        hoax(address(signerManager));
        vm.expectRevert(Errors.InvalidQuorumValue.selector);
        signerManager.updateQuorum({ quorumValue: 0 });
    }

    function testCannot_UpdateQuorum_InvalidQuorumValue_OverSignerCount() public setUpSigners {
        hoax(address(signerManager));
        vm.expectRevert(Errors.InvalidQuorumValue.selector);
        signerManager.updateQuorum({ quorumValue: 5 });
    }

    /* Helper Functions */

    function getSignersArray() private view returns (address[] memory) {
        address[] memory signers = new address[](4);

        signers[0] = users.alice;
        signers[1] = users.bob;
        signers[2] = address(0xbabe);
        signers[3] = address(0xcafe);

        return signers;
    }
}
