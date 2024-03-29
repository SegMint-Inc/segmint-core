// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./BaseTest.sol";

contract KeysTest is BaseTest {
    using stdStorage for StdStorage;

    function setUp() public override {
        super.setUp();
        kycUsers(); // KYC both Alice and Bob.

        /// Spoof storage so that Alice is a registered vault.
        string memory funcSignature = "isRegistered(address)";
        stdstore.target(address(keys)).sig(funcSignature).with_key(users.alice.account).checked_write(true);
        assertTrue(keys.isRegistered(users.alice.account));
    }

    function testCannotDeploy_Admin_ZeroAddressInvalid() public {
        vm.expectRevert(IKeys.ZeroAddressInvalid.selector);
        new Keys({ admin_: address(0), uri_: "", accessRegistry_: accessRegistry });
    }

    function testCannotDeploy_AccessRegistry_ZeroAddressInvalid() public {
        vm.expectRevert(IKeys.ZeroAddressInvalid.selector);
        new Keys({ admin_: users.admin, uri_: "", accessRegistry_: IAccessRegistry(address(0)) });
    }

    function test_CreateKeys_Invariant() public {
        startHoax(users.alice.account);
        for (uint256 i = 1; i <= type(uint8).max; i++) {
            VaultType vaultType = i % 2 == 0 ? VaultType.SINGLE : VaultType.MULTI;
            uint256 keyAmount = (i % keys.MAX_KEYS()) + 1;

            uint256 id = keys.createKeys({ amount: keyAmount, receiver: users.alice.account, vaultType: vaultType });
            assertEq(id, i);
            assertEq(keys.keysCreated(), id);
            assertEq(keys.balanceOf(users.alice.account, id), keyAmount);

            KeyConfig memory config = keys.getKeyConfig(id);
            assertEq(config.creator, users.alice.account);
            assertEq(config.vaultType, vaultType);
            assertFalse(config.isFrozen);
            assertFalse(config.isBurned);
            assertEq(config.supply, keyAmount);
        }
        assertEq(keys.keysCreated(), type(uint8).max);
    }

    function test_CreateKeys_Fuzzed(uint256 keyAmount) public {
        keyAmount = bound(keyAmount, 1, keys.MAX_KEYS());

        hoax(users.alice.account);
        uint256 id = keys.createKeys({ amount: keyAmount, receiver: users.alice.account, vaultType: VaultType.SINGLE });
        assertEq(id, 1);

        assertEq(keys.keysCreated(), 1);
        assertEq(keys.balanceOf(users.alice.account, id), keyAmount);

        KeyConfig memory config = keys.getKeyConfig(id);
        assertEq(config.creator, users.alice.account);
        assertEq(config.vaultType, VaultType.SINGLE);
        assertFalse(config.isFrozen);
        assertFalse(config.isBurned);
        assertEq(config.supply, keyAmount);
    }

    function testCannot_CreateKeys_CallerNotVault_Fuzzed(address nonVault) public {
        vm.assume(nonVault != users.alice.account);

        hoax(nonVault);
        vm.expectRevert(IKeys.CallerNotVault.selector);
        keys.createKeys({ amount: 1, receiver: nonVault, vaultType: VaultType.SINGLE });
    }

    function testCannot_CreateKeys_InvalidKeyAmount_Fuzzed(uint256 keyAmount) public {
        keyAmount = bound(keyAmount, 0, type(uint8).max);
        keyAmount = keyAmount == 0 ? 0 : keyAmount + 100;

        hoax(users.alice.account);
        vm.expectRevert(IKeys.InvalidKeyAmount.selector);
        keys.createKeys({ amount: keyAmount, receiver: users.alice.account, vaultType: VaultType.SINGLE });
    }

    function testCannot_BurnKeys_CallerNotVault_Fuzzed(address nonVault) public {
        vm.assume(nonVault != users.alice.account);

        hoax(nonVault);
        vm.expectRevert(IKeys.CallerNotVault.selector);
        keys.createKeys({ amount: 1, receiver: nonVault, vaultType: VaultType.SINGLE });
    }

    function testCannot_BurnKeys_KeysFrozen() public {
        hoax(users.alice.account);
        uint256 id = keys.createKeys({ amount: 1, receiver: users.alice.account, vaultType: VaultType.SINGLE });

        hoax(users.admin);
        keys.freezeKeys(id);

        hoax(users.alice.account);
        vm.expectRevert(IKeys.KeysFrozen.selector);
        keys.burnKeys({ holder: users.alice.account, keyId: id, amount: 1 });
    }

    function test_LendKeys_Fuzzed(uint256 keyAmount, uint256 lendAmount, uint256 lendDuration) public {
        keyAmount = bound(keyAmount, 1, keys.MAX_KEYS());
        lendAmount = bound(lendAmount, 1, keyAmount);
        lendDuration = bound(lendDuration, keys.MIN_LEND_DURATION(), keys.MAX_LEND_DURATION());

        startHoax(users.alice.account);
        uint256 id = keys.createKeys({ amount: keyAmount, receiver: users.alice.account, vaultType: VaultType.SINGLE });
        assertEq(keys.balanceOf(users.bob.account, id), 0);

        keys.lendKeys({ lendee: users.bob.account, keyId: id, lendAmount: lendAmount, lendDuration: lendDuration });
        assertEq(keys.balanceOf(users.bob.account, id), lendAmount);
        assertEq(keys.balanceOf(users.alice.account, id), keyAmount - lendAmount);

        IKeys.LendingTerms memory lendingTerms = keys.activeLends(users.bob.account, id);
        assertEq(lendingTerms.lender, users.alice.account);
        assertEq(lendingTerms.amount, lendAmount);
        assertEq(lendingTerms.expiryTime, block.timestamp + lendDuration);
    }

    function testCannot_LendKeys_ZeroAddressInvalid() public {
        uint256 keyAmount = 5;

        startHoax(users.alice.account);
        uint256 id = keys.createKeys({ amount: keyAmount, receiver: users.alice.account, vaultType: VaultType.SINGLE });

        vm.expectRevert(IKeys.ZeroAddressInvalid.selector);
        keys.lendKeys({ lendee: address(0), keyId: id, lendAmount: keyAmount, lendDuration: 1 days });
    }

    function testCannot_LendKeys_KeysFrozen() public {
        uint256 keyAmount = keys.MAX_KEYS();
        uint256 lendDuration = keys.MIN_LEND_DURATION();

        hoax(users.alice.account);
        uint256 id = keys.createKeys({ amount: keyAmount, receiver: users.alice.account, vaultType: VaultType.SINGLE });

        hoax(users.admin);
        keys.freezeKeys(id);

        hoax(users.alice.account);
        vm.expectRevert(IKeys.KeysFrozen.selector);
        keys.lendKeys({ lendee: users.bob.account, keyId: id, lendAmount: keyAmount, lendDuration: lendDuration });
    }

    function testCannot_LendKeys_InvalidAccessType() public {
        uint256 keyAmount = keys.MAX_KEYS();
        uint256 lendDuration = keys.MIN_LEND_DURATION();

        startHoax(users.alice.account);
        uint256 id = keys.createKeys({ amount: keyAmount, receiver: users.alice.account, vaultType: VaultType.SINGLE });

        vm.expectRevert(IAccessRegistry.InvalidAccessType.selector);
        keys.lendKeys({ lendee: users.eve.account, keyId: id, lendAmount: keyAmount, lendDuration: lendDuration });
    }

    function testCannot_LendKeys_CannotLendToSelf() public {
        uint256 keyAmount = keys.MAX_KEYS();
        uint256 lendDuration = keys.MIN_LEND_DURATION();

        startHoax(users.alice.account);
        uint256 id = keys.createKeys({ amount: keyAmount, receiver: users.alice.account, vaultType: VaultType.SINGLE });

        vm.expectRevert(IKeys.CannotLendToSelf.selector);
        keys.lendKeys({ lendee: users.alice.account, keyId: id, lendAmount: keyAmount, lendDuration: lendDuration });
    }

    function testCannot_LendKeys_HasActiveLend() public {
        uint256 keyAmount = keys.MAX_KEYS();
        uint256 lendDuration = keys.MIN_LEND_DURATION();

        startHoax(users.alice.account);
        uint256 id = keys.createKeys({ amount: keyAmount, receiver: users.alice.account, vaultType: VaultType.SINGLE });
        keys.lendKeys({ lendee: users.bob.account, keyId: id, lendAmount: keyAmount, lendDuration: lendDuration });

        vm.expectRevert(IKeys.HasActiveLend.selector);
        keys.lendKeys({ lendee: users.bob.account, keyId: id, lendAmount: keyAmount, lendDuration: lendDuration });
    }

    function testCannot_LendKeys_ZeroLendAmount() public {
        uint256 keyAmount = keys.MAX_KEYS();
        uint256 lendDuration = keys.MIN_LEND_DURATION();

        startHoax(users.alice.account);
        uint256 id = keys.createKeys({ amount: keyAmount, receiver: users.alice.account, vaultType: VaultType.SINGLE });
        vm.expectRevert(IKeys.ZeroLendAmount.selector);
        keys.lendKeys({ lendee: users.bob.account, keyId: id, lendAmount: 0, lendDuration: lendDuration });
    }

    function testCannot_LendKeys_InvalidLendDuration_Fuzzed(uint256 minDuration, uint256 maxDuration) public {
        minDuration = bound(minDuration, 0, keys.MIN_LEND_DURATION() - 1 seconds);
        maxDuration = bound(maxDuration, keys.MAX_LEND_DURATION() + 1 seconds, type(uint256).max);

        uint256 keyAmount = keys.MAX_KEYS();

        startHoax(users.alice.account);
        uint256 id = keys.createKeys({ amount: keyAmount, receiver: users.alice.account, vaultType: VaultType.SINGLE });

        vm.expectRevert(IKeys.InvalidLendDuration.selector);
        keys.lendKeys({ lendee: users.bob.account, keyId: id, lendAmount: keyAmount, lendDuration: minDuration });

        vm.expectRevert(IKeys.InvalidLendDuration.selector);
        keys.lendKeys({ lendee: users.bob.account, keyId: id, lendAmount: keyAmount, lendDuration: maxDuration });
    }

    function testCannot_LendKeys_CannotLendOutLendedKeys() public {
        uint256 keyAmount = 5;
        uint256 lendDuration = 1 days;

        startHoax(users.alice.account);
        uint256 id = keys.createKeys({ amount: keyAmount, receiver: users.alice.account, vaultType: VaultType.SINGLE });

        // Lend out 2 keys to Bob but transfer 1 to him.
        keys.lendKeys({ lendee: users.bob.account, keyId: id, lendAmount: 2, lendDuration: lendDuration });
        keys.safeTransferFrom({ from: users.alice.account, to: users.bob.account, id: id, value: 1, data: "" });
        assertEq(keys.balanceOf(users.bob.account, id), 3);

        IKeys.LendingTerms memory lendingTerms = keys.activeLends({ lendee: users.bob.account, keyId: id });
        assertEq(lendingTerms.lender, users.alice.account);
        assertEq(lendingTerms.amount, 2);
        assertEq(lendingTerms.expiryTime, block.timestamp + lendDuration);

        // If Bob tries to lend out 2 or 3 keys, lendKeys should revert as he only owns 1 key whilst having
        // a 3 key balance.
        changePrank(users.bob.account);
        vm.expectRevert(IKeys.CannotLendOutLendedKeys.selector);
        keys.lendKeys({ lendee: users.alice.account, keyId: id, lendAmount: 2, lendDuration: lendDuration });
        vm.expectRevert(IKeys.CannotLendOutLendedKeys.selector);
        keys.lendKeys({ lendee: users.alice.account, keyId: id, lendAmount: 3, lendDuration: lendDuration });

        // If Bob lends out 1 key, that he owns due to the previous transfer, it should work.
        keys.lendKeys({ lendee: users.alice.account, keyId: id, lendAmount: 1, lendDuration: lendDuration });

        lendingTerms = keys.activeLends({ lendee: users.alice.account, keyId: id });
        assertEq(lendingTerms.lender, users.bob.account);
        assertEq(lendingTerms.amount, 1);
        assertEq(lendingTerms.expiryTime, block.timestamp + lendDuration);
    }

    function testCannot_LendKeys_NonExistentKeyId_Fuzzed(uint256 id, uint256 amount) public {
        amount = bound(amount, 1, type(uint256).max);

        hoax(users.alice.account);
        vm.expectRevert();
        keys.lendKeys({ lendee: users.bob.account, keyId: id, lendAmount: amount, lendDuration: 1 days });
    }

    function test_ReclaimKeys() public {
        uint256 keyAmount = keys.MAX_KEYS();
        uint256 lendDuration = keys.MIN_LEND_DURATION();

        startHoax(users.alice.account);
        uint256 id = keys.createKeys({ amount: keyAmount, receiver: users.alice.account, vaultType: VaultType.SINGLE });
        keys.lendKeys({ lendee: users.bob.account, keyId: id, lendAmount: keyAmount, lendDuration: lendDuration });
        assertEq(keys.balanceOf(users.alice.account, id), 0);
        assertEq(keys.balanceOf(users.bob.account, id), keyAmount);

        IKeys.LendingTerms memory lendingTerms = keys.activeLends({ lendee: users.bob.account, keyId: id });
        assertEq(lendingTerms.lender, users.alice.account);
        assertEq(lendingTerms.amount, keyAmount);
        assertEq(lendingTerms.expiryTime, block.timestamp + lendDuration);

        uint256 lendExpiryTime = keys.activeLends({ lendee: users.bob.account, keyId: id }).expiryTime;
        vm.warp(lendExpiryTime);

        keys.reclaimKeys({ lendee: users.bob.account, keyId: id });
        assertEq(keys.balanceOf(users.alice.account, id), keyAmount);
        assertEq(keys.balanceOf(users.bob.account, id), 0);

        lendingTerms = keys.activeLends({ lendee: users.bob.account, keyId: id });
        assertEq(lendingTerms.lender, address(0));
        assertEq(lendingTerms.amount, 0);
        assertEq(lendingTerms.expiryTime, 0);
    }

    function testCannot_ReclaimKeys_KeysFrozen() public {
        uint256 keyAmount = keys.MAX_KEYS();
        uint256 lendDuration = keys.MIN_LEND_DURATION();

        startHoax(users.alice.account);
        uint256 id = keys.createKeys({ amount: keyAmount, receiver: users.alice.account, vaultType: VaultType.SINGLE });
        keys.lendKeys({ lendee: users.bob.account, keyId: id, lendAmount: keyAmount, lendDuration: lendDuration });
        vm.stopPrank();

        hoax(users.admin);
        keys.freezeKeys(id);

        uint256 lendExpiryTime = keys.activeLends({ lendee: users.bob.account, keyId: id }).expiryTime;
        vm.warp(lendExpiryTime);

        hoax(users.alice.account);
        vm.expectRevert(IKeys.KeysFrozen.selector);
        keys.reclaimKeys({ lendee: users.bob.account, keyId: id });
    }

    function testCannot_ReclaimKeys_NoActiveLend() public {
        uint256 keyAmount = keys.MAX_KEYS();

        startHoax(users.alice.account);
        uint256 id = keys.createKeys({ amount: keyAmount, receiver: users.alice.account, vaultType: VaultType.SINGLE });

        vm.expectRevert(IKeys.NoActiveLend.selector);
        keys.reclaimKeys({ lendee: users.bob.account, keyId: id });
    }

    function testCannot_ReclaimKeys_LendStillActive() public {
        uint256 keyAmount = keys.MAX_KEYS();
        uint256 lendDuration = keys.MIN_LEND_DURATION();

        startHoax(users.alice.account);
        uint256 id = keys.createKeys({ amount: keyAmount, receiver: users.alice.account, vaultType: VaultType.SINGLE });
        keys.lendKeys({ lendee: users.bob.account, keyId: id, lendAmount: keyAmount, lendDuration: lendDuration });

        for (uint256 i = 0; i < type(uint8).max; i++) {
            uint256 lendExpiryTime = keys.activeLends({ lendee: users.bob.account, keyId: id }).expiryTime;
            lendExpiryTime = bound(lendExpiryTime, 0, lendExpiryTime - 1 seconds);
            vm.warp(lendExpiryTime);

            vm.expectRevert(IKeys.LendStillActive.selector);
            keys.reclaimKeys({ lendee: users.bob.account, keyId: id });
        }
    }

    function test_RegisterVault(address newVault) public {
        vm.assume(newVault != address(0));

        hoax(address(vaultFactory));
        vm.expectEmit({ checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true });
        emit VaultRegistered({ registeredVault: newVault });
        keys.registerVault({ vault: newVault });

        assertTrue(keys.isRegistered(newVault));
    }

    function testCannot_RegisterVault_Unauthorized(address nonFactory) public {
        /// @dev Can't figure out why but `0x1c4083413Cf0051f90584908ee304F96FcF9128d` passes.
        vm.assume(nonFactory != address(vaultFactory) && nonFactory != 0x1c4083413Cf0051f90584908ee304F96FcF9128d);

        hoax(nonFactory);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        keys.registerVault({ vault: nonFactory });
    }

    function testCannot_RegisterVault_ZeroAddressInvalid() public {
        hoax(address(vaultFactory));
        vm.expectRevert(IKeys.ZeroAddressInvalid.selector);
        keys.registerVault({ vault: address(0) });
    }

    function test_FreezeKeys_Fuzzed(uint256 keyId) public {
        hoax(users.admin);
        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: false, checkData: true });
        emit KeyFrozen({ admin: users.admin, keyId: keyId });
        keys.freezeKeys(keyId);

        assertTrue(keys.getKeyConfig(keyId).isFrozen);
    }

    function testCannot_FreezeKeys_Unauthorized_Fuzzed(address nonAdmin, uint256 keyId) public {
        vm.assume(nonAdmin != users.admin);

        hoax(nonAdmin);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        keys.freezeKeys(keyId);
    }

    function test_UnfreezeKeys_Fuzzed(uint256 keyId) public {
        hoax(users.admin);
        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: false, checkData: true });
        emit KeyUnfrozen({ admin: users.admin, keyId: keyId });
        keys.unfreezeKeys(keyId);

        assertFalse(keys.getKeyConfig(keyId).isFrozen);
    }

    function testCannot_UnfreezeKeys_Unauthorized_Fuzzed(address nonAdmin, uint256 keyId) public {
        vm.assume(nonAdmin != users.admin);

        hoax(nonAdmin);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        keys.unfreezeKeys(keyId);
    }

    function testCannot_ClearLendingTerms_Unauthorized(address nonKeyExchange) public {
        vm.assume(nonKeyExchange != address(keyExchange));

        hoax(nonKeyExchange);
        vm.expectRevert(IKeys.CallerNotExchange.selector);
        keys.clearLendingTerms({ lendee: nonKeyExchange, keyId: 0 });
    }

    function test_SetAccessRegistry_Fuzzed(IAccessRegistry newAccessRegistry) public {
        vm.assume(address(newAccessRegistry) != address(0));
        IAccessRegistry oldAccessRegistry = keys.accessRegistry();

        hoax(users.admin);
        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: false, checkData: true });
        emit AccessRegistryUpdated({ oldAccessRegistry: oldAccessRegistry, newAccessRegistry: newAccessRegistry });
        keys.setAccessRegistry(newAccessRegistry);

        assertEq(keys.accessRegistry(), newAccessRegistry);
    }

    function testCannot_SetAccessRegistry_Unauthorized(address nonAdmin) public {
        vm.assume(nonAdmin != users.admin && nonAdmin != 0x2a07706473244BC757E10F2a9E86fB532828afe3);

        hoax(nonAdmin);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        keys.setAccessRegistry(IAccessRegistry(address(0x01)));
    }

    function testCannot_SetAccessRegistry_ZeroAddressInvalid() public {
        hoax(users.admin);
        vm.expectRevert(IAccessRegistry.ZeroAddressInvalid.selector);
        keys.setAccessRegistry({ newAccessRegistry: IAccessRegistry(address(0)) });
    }

    function test_SetKeyExchange_Fuzzed(address newKeyExchange) public {
        vm.assume(newKeyExchange != address(0));
        address oldKeyExchange = keys.keyExchange();

        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: false, checkData: true });
        emit KeyExchangeUpdated({ oldKeyExchange: oldKeyExchange, newKeyExchange: newKeyExchange });
        keys.setKeyExchange(newKeyExchange);

        assertEq(keys.keyExchange(), newKeyExchange);
    }

    function testCannot_SetKeyExchange_Unauthorized_Fuzzed(address nonOwner) public {
        vm.assume(nonOwner != keys.owner());

        hoax(nonOwner);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        keys.setKeyExchange(nonOwner);
    }

    function testCannot_SetKeyExchange_ZeroAddressInvalid() public {
        vm.expectRevert(IKeys.ZeroAddressInvalid.selector);
        keys.setKeyExchange({ newKeyExchange: address(0) });
    }

    function test_SetURI_Fuzzed(string memory newURI, uint256 tokenId) public {
        hoax(users.admin);
        vm.expectEmit();
        emit URIUpdated({ newURI: newURI });
        keys.setURI(newURI);

        assertEq(keys.uri(tokenId), string(abi.encodePacked(newURI, vm.toString(tokenId))));
    }

    function testCannot_SetURI_Unauthorized_Fuzzed(address nonAdmin) public {
        vm.assume(nonAdmin != users.admin && nonAdmin != 0x2a07706473244BC757E10F2a9E86fB532828afe3);

        hoax(nonAdmin);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        keys.setURI("");
    }

    /* safeTransferFrom Tests */

    function test_SafeTransferFrom_Fuzzed(uint256 amount) public {
        uint256 keyAmount = keys.MAX_KEYS();
        amount = bound(amount, 1, keyAmount);

        startHoax(users.alice.account);
        uint256 id = keys.createKeys({ amount: keyAmount, receiver: users.alice.account, vaultType: VaultType.SINGLE });
        assertEq(keys.balanceOf(users.alice.account, id), keyAmount);
        assertEq(keys.balanceOf(users.bob.account, id), 0);

        keys.safeTransferFrom(users.alice.account, users.bob.account, id, amount, "");
        assertEq(keys.balanceOf(users.alice.account, id), keyAmount - amount);
        assertEq(keys.balanceOf(users.bob.account, id), amount);
    }

    function testCannot_SafeTransferFrom_OperatorBlocked_Fuzzed() public {
        uint256 keySupply = 1;
        address badOperator = address(0xCAFE);

        hoax(users.alice.account);
        uint256 id = keys.createKeys({ amount: keySupply, receiver: users.alice.account, vaultType: VaultType.SINGLE });

        hoax(badOperator);
        vm.expectRevert(IOperatorFilter.OperatorBlocked.selector);
        keys.safeTransferFrom(users.alice.account, users.bob.account, id, keySupply, "");
    }

    function testCannot_SafeTransferFrom_MissingApproval_Fuzzed(address badActor) public {
        vm.assume(badActor != users.alice.account);
        uint256 keyAmount = keys.MAX_KEYS();

        hoax(users.alice.account);
        uint256 id = keys.createKeys({ amount: keyAmount, receiver: users.alice.account, vaultType: VaultType.SINGLE });

        hoax(badActor);
        vm.expectRevert();
        keys.safeTransferFrom(users.alice.account, badActor, id, keyAmount, "");
    }

    function testCannot_SafeTransferFrom_InvalidAccessType() public {
        uint256 keyAmount = keys.MAX_KEYS();

        startHoax(users.alice.account);
        uint256 id = keys.createKeys({ amount: keyAmount, receiver: users.alice.account, vaultType: VaultType.SINGLE });
        vm.expectRevert(IAccessRegistry.InvalidAccessType.selector);
        keys.safeTransferFrom(users.alice.account, users.eve.account, id, keyAmount, "");
    }

    function testCannot_SafeTransferFrom_KeysFrozen() public {
        uint256 keyAmount = keys.MAX_KEYS();

        hoax(users.alice.account);
        uint256 id = keys.createKeys({ amount: keyAmount, receiver: users.alice.account, vaultType: VaultType.SINGLE });

        hoax(users.admin);
        keys.freezeKeys(id);

        hoax(users.alice.account);
        vm.expectRevert(IKeys.KeysFrozen.selector);
        keys.safeTransferFrom(users.alice.account, users.bob.account, id, keyAmount, "");
    }

    function testCannot_SafeTransferFrom_ZeroKeyTransfer() public {
        uint256 keyAmount = keys.MAX_KEYS();

        startHoax(users.alice.account);
        uint256 id = keys.createKeys({ amount: keyAmount, receiver: users.alice.account, vaultType: VaultType.SINGLE });

        vm.expectRevert(IKeys.ZeroKeyTransfer.selector);
        keys.safeTransferFrom(users.alice.account, users.bob.account, id, 0, "");
    }

    function testCannot_SafeTransferFrom_CannotTransferLendedKeys_Fuzzed(uint256 lendAmount) public {
        hoax(users.admin);
        /// For this test, grant Eve KYC access.
        accessRegistry.modifyAccessType(users.eve.account, IAccessRegistry.AccessType.UNRESTRICTED);

        uint256 keyAmount = keys.MAX_KEYS();
        uint256 lendDuration = keys.MIN_LEND_DURATION();

        lendAmount = bound(lendAmount, 1, keyAmount - 1);

        startHoax(users.alice.account);
        uint256 id = keys.createKeys({ amount: keyAmount, receiver: users.alice.account, vaultType: VaultType.SINGLE });
        keys.lendKeys({ lendee: users.bob.account, keyId: id, lendAmount: lendAmount, lendDuration: lendDuration });
        vm.stopPrank();

        assertEq(keys.balanceOf(users.alice.account, id), keyAmount - lendAmount);
        assertEq(keys.balanceOf(users.bob.account, id), lendAmount);
        assertEq(keys.balanceOf(users.eve.account, id), 0);

        /// Ensure all keys owned by Bob are not transferrable.
        startHoax(users.bob.account);
        for (uint256 amount = 1; amount <= lendAmount; amount++) {
            vm.expectRevert(IKeys.CannotTransferLendedKeys.selector);
            keys.safeTransferFrom(users.bob.account, users.eve.account, id, amount, "");
        }
        vm.stopPrank();

        /// Give Bob 1 key via transfer.
        hoax(users.alice.account);
        keys.safeTransferFrom(users.alice.account, users.bob.account, id, 1, "");

        assertEq(keys.balanceOf(users.alice.account, id), keyAmount - lendAmount - 1);
        assertEq(keys.balanceOf(users.bob.account, id), lendAmount + 1);
        assertEq(keys.balanceOf(users.eve.account, id), 0);

        /// Ensure Bob can give Eve 1 key.
        hoax(users.bob.account);
        keys.safeTransferFrom(users.bob.account, users.eve.account, id, 1, "");

        assertEq(keys.balanceOf(users.alice.account, id), keyAmount - lendAmount - 1);
        assertEq(keys.balanceOf(users.bob.account, id), lendAmount);
        assertEq(keys.balanceOf(users.eve.account, id), 1);

        /// Ensure all keys owned by Bob are not transferrable.
        startHoax(users.bob.account);
        for (uint256 amount = 1; amount <= lendAmount; amount++) {
            vm.expectRevert(IKeys.CannotTransferLendedKeys.selector);
            keys.safeTransferFrom(users.bob.account, users.eve.account, id, amount, "");
        }
        vm.stopPrank();
    }

    /* safeBatchTransferFrom Tests */

    function test_SafeBatchTransferFrom_Fuzzed(uint256 numKeys) public {
        numKeys = bound(numKeys, 1, 10);

        uint256 maxKeys = keys.MAX_KEYS();
        uint256[] memory ids = new uint256[](numKeys);
        uint256[] memory amounts = new uint256[](numKeys);

        startHoax(users.alice.account);
        for (uint256 i = 0; i < numKeys; i++) {
            uint256 id =
                keys.createKeys({ amount: maxKeys, receiver: users.alice.account, vaultType: VaultType.SINGLE });

            ids[i] = id;
            amounts[i] = i + 1; // Assign a varying amount of keys to be transferred.

            assertEq(keys.balanceOf(users.alice.account, id), maxKeys);
            assertEq(keys.balanceOf(users.bob.account, id), 0);
        }

        keys.safeBatchTransferFrom(users.alice.account, users.bob.account, ids, amounts, "");

        for (uint256 i = 0; i < numKeys; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            assertEq(keys.balanceOf(users.alice.account, id), maxKeys - amount);
            assertEq(keys.balanceOf(users.bob.account, id), amount);
        }
    }

    function testCannot_SafeBatchTransferFrom_OperatorBlocked() public {
        uint256 keySupply = 1;
        address badOperator = address(0xCAFE);

        uint256[] memory ids = new uint256[](keySupply);
        uint256[] memory amounts = new uint256[](keySupply);

        hoax(users.alice.account);
        uint256 id = keys.createKeys({ amount: keySupply, receiver: users.alice.account, vaultType: VaultType.SINGLE });

        ids[0] = id;
        amounts[0] = keySupply;

        hoax(badOperator);
        vm.expectRevert(IOperatorFilter.OperatorBlocked.selector);
        keys.safeBatchTransferFrom(users.alice.account, users.bob.account, ids, amounts, "");
    }

    function testCannot_SafeBatchTransferFrom_ArrayLengthMismatch_Fuzzed(uint256 a, uint256 b) public {
        vm.assume(a != 0 && a < type(uint8).max);
        vm.assume(b != 0 && b < type(uint8).max);
        vm.assume(a != b);

        hoax(users.alice.account);
        vm.expectRevert(IKeys.ArrayLengthMismatch.selector);
        keys.safeBatchTransferFrom({
            from: users.alice.account,
            to: users.bob.account,
            ids: new uint256[](a),
            amounts: new uint256[](b),
            data: ""
        });
    }

    function testCannot_SafeBatchTransferFrom_MissingApproval() public {
        uint256 numKeys = 10;
        uint256 maxKeys = keys.MAX_KEYS();

        uint256[] memory ids = new uint256[](numKeys);
        uint256[] memory amounts = new uint256[](numKeys);

        startHoax(users.alice.account);
        for (uint256 i = 0; i < numKeys; i++) {
            uint256 id =
                keys.createKeys({ amount: maxKeys, receiver: users.alice.account, vaultType: VaultType.SINGLE });

            ids[i] = id;
            amounts[i] = i + 1; // Assign a varying amount of keys to be transferred.

            assertEq(keys.balanceOf(users.alice.account, id), maxKeys);
            assertEq(keys.balanceOf(users.bob.account, id), 0);
        }
        vm.stopPrank();

        hoax(users.bob.account);
        vm.expectRevert();
        keys.safeBatchTransferFrom(users.alice.account, users.bob.account, ids, amounts, "");
    }

    function testCannot_SafeBatchTransferFrom_InvalidAccessType() public {
        uint256 numKeys = 10;
        uint256 maxKeys = keys.MAX_KEYS();

        uint256[] memory ids = new uint256[](numKeys);
        uint256[] memory amounts = new uint256[](numKeys);

        startHoax(users.alice.account);
        for (uint256 i = 0; i < numKeys; i++) {
            uint256 id =
                keys.createKeys({ amount: maxKeys, receiver: users.alice.account, vaultType: VaultType.SINGLE });

            ids[i] = id;
            amounts[i] = i + 1; // Assign a varying amount of keys to be transferred.

            assertEq(keys.balanceOf(users.alice.account, id), maxKeys);
            assertEq(keys.balanceOf(users.bob.account, id), 0);
        }

        vm.expectRevert(IAccessRegistry.InvalidAccessType.selector);
        keys.safeBatchTransferFrom(users.alice.account, users.eve.account, ids, amounts, "");
    }

    function testCannot_SafeBatchTransferFrom_KeysFrozen() public {
        uint256 numKeys = 10;
        uint256 maxKeys = keys.MAX_KEYS();

        uint256[] memory ids = new uint256[](numKeys);
        uint256[] memory amounts = new uint256[](numKeys);

        startHoax(users.alice.account);
        for (uint256 i = 0; i < numKeys; i++) {
            uint256 id =
                keys.createKeys({ amount: maxKeys, receiver: users.alice.account, vaultType: VaultType.SINGLE });

            ids[i] = id;
            amounts[i] = i + 1; // Assign a varying amount of keys to be transferred.

            assertEq(keys.balanceOf(users.alice.account, id), maxKeys);
            assertEq(keys.balanceOf(users.bob.account, id), 0);
        }
        vm.stopPrank();

        /// Freeze the last key ID in the array.
        hoax(users.admin);
        keys.freezeKeys(ids[numKeys - 1]);

        hoax(users.alice.account);
        vm.expectRevert(IKeys.KeysFrozen.selector);
        keys.safeBatchTransferFrom(users.alice.account, users.bob.account, ids, amounts, "");
    }

    function testCannot_SafeBatchTransferFrom_ZeroKeyTransfer() public {
        uint256 numKeys = 10;
        uint256 maxKeys = keys.MAX_KEYS();

        uint256[] memory ids = new uint256[](numKeys);
        uint256[] memory amounts = new uint256[](numKeys);

        startHoax(users.alice.account);
        for (uint256 i = 0; i < numKeys; i++) {
            uint256 id =
                keys.createKeys({ amount: maxKeys, receiver: users.alice.account, vaultType: VaultType.SINGLE });

            ids[i] = id;
            amounts[i] = i + 1; // Assign a varying amount of keys to be transferred.

            assertEq(keys.balanceOf(users.alice.account, id), maxKeys);
            assertEq(keys.balanceOf(users.bob.account, id), 0);
        }

        /// Make the transfer amount for the last index 0.
        amounts[numKeys - 1] = 0;

        vm.expectRevert(IKeys.ZeroKeyTransfer.selector);
        keys.safeBatchTransferFrom(users.alice.account, users.bob.account, ids, amounts, "");
    }

    /* isApprovedForAll Tests */

    function test_IsApproveForAll_Fuzzed(address nonOperator) public {
        vm.assume(nonOperator != address(keyExchange));

        bool approved = keys.isApprovedForAll(users.alice.account, keys.keyExchange());
        assertTrue(approved);

        approved = keys.isApprovedForAll(users.alice.account, nonOperator);
        assertFalse(approved);
    }

    /* Operator Filterer Tests */

    function test_UpdateOperatorStatus_Fuzzed(address operator, bool status) public {
        hoax(users.admin);
        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: false, checkData: false });
        emit OperatorStatusUpdated({ operator: operator, status: status });
        keys.updateOperatorStatus(operator, status);

        assertEq(keys.isOperatorAllowed(operator), status);
    }

    function testCannot_UpdateOperatorStatus_Unauthorized(address nonAdmin) public {
        vm.assume(nonAdmin != users.admin && nonAdmin != 0x2a07706473244BC757E10F2a9E86fB532828afe3);

        hoax(nonAdmin);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        keys.updateOperatorStatus({ operator: nonAdmin, isAllowed: false });
    }

    function testCannot_SetApprovalForAll_OperatorBlocked_Fuzzed(address blockedOperator) public {
        hoax(users.alice.account);
        vm.expectRevert(IOperatorFilter.OperatorBlocked.selector);
        keys.setApprovalForAll(blockedOperator, true);
    }

    /* Edge Cases */

    function test_SafeTransferFrom_UpdatesLendingTerms() public {
        uint256 keyAmount = keys.MAX_KEYS();
        uint256 lendAmount = bound(keyAmount, 1, keyAmount);
        uint256 lendDuration = keys.MIN_LEND_DURATION();

        startHoax(users.alice.account);
        uint256 id = keys.createKeys({ amount: keyAmount, receiver: users.alice.account, vaultType: VaultType.SINGLE });
        assertEq(keys.balanceOf(users.alice.account, id), keyAmount);
        assertEq(keys.balanceOf(users.bob.account, id), 0);

        keys.lendKeys({ lendee: users.bob.account, keyId: id, lendAmount: lendAmount, lendDuration: lendDuration });
        assertEq(keys.balanceOf(users.alice.account, id), keyAmount - lendAmount);
        assertEq(keys.balanceOf(users.bob.account, id), lendAmount);
        vm.stopPrank();

        IKeys.LendingTerms memory lendingTerms = keys.activeLends({ lendee: users.bob.account, keyId: id });
        assertEq(lendingTerms.lender, users.alice.account);
        assertEq(lendingTerms.amount, lendAmount);
        assertEq(lendingTerms.expiryTime, block.timestamp + lendDuration);

        /// Return all keys one by one leaving a single key on lend and ensure lending terms updates correctly.
        startHoax(users.bob.account);
        for (uint256 i = 1; i < lendAmount; i++) {
            keys.safeTransferFrom(users.bob.account, users.alice.account, id, 1, "");

            lendingTerms = keys.activeLends({ lendee: users.bob.account, keyId: id });
            assertEq(lendingTerms.lender, users.alice.account);
            assertEq(lendingTerms.amount, lendAmount - i);
            assertEq(lendingTerms.expiryTime, block.timestamp + lendDuration);
        }

        /// Return the final key and ensure the lending terms are fully cleared.
        keys.safeTransferFrom(users.bob.account, users.alice.account, id, 1, "");

        lendingTerms = keys.activeLends({ lendee: users.bob.account, keyId: id });
        assertEq(lendingTerms.lender, address(0));
        assertEq(lendingTerms.amount, 0);
        assertEq(lendingTerms.expiryTime, 0);
    }

    function test_SafeBatchTransferFrom_UpdatesLendingTerms() public {
        uint256 numKeys = 10;
        uint256 maxKeys = keys.MAX_KEYS();
        uint256 lendDuration = keys.MIN_LEND_DURATION();

        uint256[] memory ids = new uint256[](numKeys);
        uint256[] memory amounts = new uint256[](numKeys);

        startHoax(users.alice.account);
        for (uint256 i = 0; i < numKeys; i++) {
            uint256 id =
                keys.createKeys({ amount: maxKeys, receiver: users.alice.account, vaultType: VaultType.SINGLE });

            ids[i] = id;
            amounts[i] = i + 1; // Assign a varying amount of keys to be transferred.

            assertEq(keys.balanceOf(users.alice.account, id), maxKeys);
            assertEq(keys.balanceOf(users.bob.account, id), 0);
        }

        /// Lend a varying amount of keys to Bob.
        for (uint256 i = 0; i < numKeys; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            keys.lendKeys({ lendee: users.bob.account, keyId: id, lendAmount: amount, lendDuration: lendDuration });
            assertEq(keys.balanceOf(users.alice.account, id), maxKeys - amount);
            assertEq(keys.balanceOf(users.bob.account, id), amount);

            IKeys.LendingTerms memory lendingTerms = keys.activeLends({ lendee: users.bob.account, keyId: id });
            assertEq(lendingTerms.lender, users.alice.account);
            assertEq(lendingTerms.amount, amount);
            assertEq(lendingTerms.expiryTime, block.timestamp + lendDuration);
        }
        vm.stopPrank();

        /// Return all keys and ensure lending terms updates correctly.
        hoax(users.bob.account);
        keys.safeBatchTransferFrom(users.bob.account, users.alice.account, ids, amounts, "");

        for (uint256 i = 0; i < numKeys; i++) {
            IKeys.LendingTerms memory lendingTerms = keys.activeLends({ lendee: users.bob.account, keyId: ids[i] });
            assertEq(lendingTerms.lender, address(0));
            assertEq(lendingTerms.amount, 0);
            assertEq(lendingTerms.expiryTime, 0);
        }
    }
}
