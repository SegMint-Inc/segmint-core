// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./BaseTest.sol";

contract KeysTest is BaseTest {
    using stdStorage for StdStorage;

    function setUp() public override {
        super.setUp();
        kycUsers(); // KYC both Alice and Bob.

        /// Spoof storage so that Alice is a registered vault.
        stdstore.target(address(keys)).sig("isRegistered(address)").with_key(users.alice.account).checked_write(true);
        assertTrue(keys.isRegistered(users.alice.account));   
    }

    function test_CreateKeys_Fuzzed(uint256 keyAmount) public {
        keyAmount = bound(keyAmount, 1, keys.MAX_KEYS());
        uint256 oldKeysCreated = keys.keysCreated();

        hoax(users.alice.account);
        uint256 newKeyId = keys.createKeys({ amount: keyAmount, receiver: users.alice.account, vaultType: VaultType.SINGLE });

        uint256 newKeysCreated = keys.keysCreated();
        assertEq(newKeysCreated, oldKeysCreated + 1);
        assertEq(keys.balanceOf({ account: users.alice.account, id: newKeyId }), keyAmount);
        
        KeyConfig memory keyConfig = keys.getKeyConfig(newKeyId);
        assertEq(keyConfig.creator, users.alice.account);
        assertEq(keyConfig.vaultType, VaultType.SINGLE);
        assertFalse(keyConfig.isFrozen);
        assertFalse(keyConfig.isBurned);
        assertEq(keyConfig.supply, keyAmount);
    }

    function testCannot_CreateKeys_CallerNotRegistered_Fuzzed(address nonRegistered) public {        
        vm.assume(nonRegistered != users.alice.account);
    
        hoax(nonRegistered);
        vm.expectRevert(IKeys.CallerNotVault.selector);
        keys.createKeys({ amount: 1, receiver: nonRegistered, vaultType: VaultType.SINGLE });
    }

    function testCannot_CreateKeys_InvalidKeyAmount() public {
        uint256 overMaxKeys = keys.MAX_KEYS() + 1;

        startHoax(users.alice.account);
        vm.expectRevert(IKeys.InvalidKeyAmount.selector);
        keys.createKeys({ amount: 0, receiver: users.alice.account, vaultType: VaultType.SINGLE });
        vm.expectRevert(IKeys.InvalidKeyAmount.selector);
        keys.createKeys({ amount: overMaxKeys, receiver: users.alice.account, vaultType: VaultType.SINGLE });
    }

    function test_BurnKeys_Fuzzed(uint256 keyAmount) public {
        keyAmount = bound(keyAmount, 1, keys.MAX_KEYS());

        startHoax(users.alice.account);
        uint256 keyId = _createKeys(keyAmount);
        assertEq(keys.balanceOf({ account: users.alice.account, id: keyId }), keyAmount);
        assertFalse(keys.getKeyConfig(keyId).isBurned);

        keys.burnKeys({ holder: users.alice.account, keyId: keyId, amount: keyAmount });
        assertEq(keys.balanceOf({ account: users.alice.account, id: keyId }), 0);
        assertTrue(keys.getKeyConfig(keyId).isBurned);
    }

    function testCannot_BurnKeys_CallerNotRegistered_Fuzzed(address nonRegistered) public {
        vm.assume(nonRegistered != users.alice.account);

        hoax(nonRegistered);
        vm.expectRevert(IKeys.CallerNotVault.selector);
        keys.createKeys({ amount: 1, receiver: nonRegistered, vaultType: VaultType.SINGLE });
    }

    function testCannot_BurnKeys_KeysFrozen_Fuzzed(uint256 keyAmount) public {
        keyAmount = bound(keyAmount, 1, keys.MAX_KEYS());

        hoax(users.alice.account);
        uint256 keyId = _createKeys(keyAmount);

        hoax(users.admin);
        keys.freezeKeys(keyId);

        hoax(users.alice.account);
        vm.expectRevert(IKeys.KeysFrozen.selector);
        keys.burnKeys({ holder: users.alice.account, keyId: keyId, amount: keyAmount});
    }

    function test_LendKeys_Fuzzed(uint256 lendAmount, uint256 lendDuration) public {
        uint256 keyAmount = keys.MAX_KEYS();
        lendAmount = bound(lendAmount, 1, keyAmount);
        lendDuration = bound(lendDuration, keys.MIN_LEND_DURATION(), keys.MAX_LEND_DURATION());

        startHoax(users.alice.account);
        uint256 keyId = _createKeys(keyAmount);
        assertEq(keys.balanceOf({ account: users.bob.account, id: keyId }), 0);

        keys.lendKeys({ lendee: users.bob.account, keyId: keyId, lendAmount: lendAmount, lendDuration: lendDuration });
        assertEq(keys.balanceOf({ account: users.bob.account, id: keyId }), lendAmount);
        assertEq(keys.balanceOf({ account: users.alice.account, id: keyId }), keyAmount - lendAmount);

        IKeys.LendingTerms memory lendingTerms = keys.activeLends(users.bob.account, keyId);
        assertEq(lendingTerms.lender, users.alice.account);
        assertEq(lendingTerms.amount, lendAmount);
        assertEq(lendingTerms.expiryTime, block.timestamp + lendDuration);
    }

    function testCannot_LendKeys_KeysFrozen_Fuzzed(uint256 lendAmount, uint256 lendDuration) public {
        uint256 keyAmount = keys.MAX_KEYS();
        lendAmount = bound(lendAmount, 1, keyAmount);
        lendDuration = bound(lendDuration, keys.MIN_LEND_DURATION(), keys.MAX_LEND_DURATION());
        
        hoax(users.alice.account);
        uint256 keyId = _createKeys(keyAmount);
        
        hoax(users.admin);
        keys.freezeKeys(keyId);

        hoax(users.alice.account);
        vm.expectRevert(IKeys.KeysFrozen.selector);
        keys.lendKeys({ lendee: users.bob.account, keyId: keyId, lendAmount: lendAmount, lendDuration: lendDuration });
    }

    function testCannot_LendKeys_InvalidAccessType() public {
        uint256 keyAmount = keys.MAX_KEYS();

        startHoax(users.alice.account);
        uint256 keyId = _createKeys(keyAmount);
        vm.expectRevert(IKYCRegistry.InvalidAccessType.selector);
        keys.lendKeys({ lendee: users.eve.account, keyId: keyId, lendAmount: keyAmount, lendDuration: 1 days });
    }

    function testCannot_LendKeys_CannotLendToSelf() public {
        uint256 keyAmount = keys.MAX_KEYS();

        startHoax(users.alice.account);
        uint256 keyId = _createKeys(keyAmount);
        vm.expectRevert(IKeys.CannotLendToSelf.selector);
        keys.lendKeys({ lendee: users.alice.account, keyId: keyId, lendAmount: keyAmount, lendDuration: 1 days });
    }

    function testCannot_LendKeys_HasActiveLend() public {
        uint256 keyAmount = keys.MAX_KEYS();

        startHoax(users.alice.account);
        uint256 keyId = _createKeys(keyAmount);
        keys.lendKeys({ lendee: users.bob.account, keyId: keyId, lendAmount: keyAmount, lendDuration: 1 days });
        vm.expectRevert(IKeys.HasActiveLend.selector);
        keys.lendKeys({ lendee: users.bob.account, keyId: keyId, lendAmount: keyAmount, lendDuration: 1 days });
    }

    function testCannot_LendKeys_ZeroLendAmount() public {
        startHoax(users.alice.account);
        uint256 keyId = _createKeys(keys.MAX_KEYS());
        vm.expectRevert(IKeys.ZeroLendAmount.selector);
        keys.lendKeys({ lendee: users.bob.account, keyId: keyId, lendAmount: 0, lendDuration: 1 days });
    }

    function testCannot_LendKeys_InvalidLendDuration() public {
        uint256 badMinDuration = keys.MIN_LEND_DURATION() - 1 seconds;
        uint256 badMaxDuration = keys.MAX_LEND_DURATION() + 1 seconds;
        uint256 keyAmount = keys.MAX_KEYS();

        startHoax(users.alice.account);
        uint256 keyId = _createKeys(keyAmount);
        vm.expectRevert(IKeys.InvalidLendDuration.selector);
        keys.lendKeys({ lendee: users.bob.account, keyId: keyId, lendAmount: keyAmount, lendDuration: badMinDuration });
        vm.expectRevert(IKeys.InvalidLendDuration.selector);
        keys.lendKeys({ lendee: users.bob.account, keyId: keyId, lendAmount: keyAmount, lendDuration: badMaxDuration });
    }

    function testCannot_LendKeys_NonExistentKeyId_Fuzzed(uint256 keyId, uint256 keyAmount) public {
        keyId = bound(keyId, 2, type(uint256).max);
        keyAmount = bound(keyAmount, 1, type(uint256).max);

        hoax(users.alice.account);
        vm.expectRevert();
        keys.lendKeys({ lendee: users.bob.account, keyId: keyId, lendAmount: keyAmount, lendDuration: 3 days });
    }

    function testCannot_TransferKeys_OnLend_OverFreeKeyBalance_Fuzzed(uint256 lendAmount, uint256 lendDuration) public {
        /// For this test, grant Eve KYC access.
        hoax(users.admin);
        kycRegistry.modifyAccessType({ account: users.eve.account, newAccessType: IKYCRegistry.AccessType.RESTRICTED });

        uint256 keyAmount = keys.MAX_KEYS();
        lendAmount = bound(lendAmount, 1, keyAmount);
        lendDuration = bound(lendDuration, keys.MIN_LEND_DURATION(), keys.MAX_LEND_DURATION());

        startHoax(users.alice.account);
        uint256 keyId = _createKeys(keyAmount);
        keys.lendKeys({ lendee: users.bob.account, keyId: keyId, lendAmount: keyAmount, lendDuration: lendDuration });
        vm.stopPrank();

        startHoax(users.bob.account);
        for (uint256 i = 1; i <= lendAmount; i++) {
            vm.expectRevert(IKeys.OverFreeKeyBalance.selector);
            keys.safeTransferFrom({
                from: users.bob.account,
                to: users.eve.account,
                id: keyId,
                value: i,
                data: ""
            });
        }
    }

    function test_TransferKeys_OnLend_WithFreeKeyBalance(uint256 freeKeyAmount) public {
        /// For this test, grant Eve KYC access.
        hoax(users.admin);
        kycRegistry.modifyAccessType({ account: users.eve.account, newAccessType: IKYCRegistry.AccessType.RESTRICTED });

        uint256 keyAmount = keys.MAX_KEYS();
        uint256 lendAmount = 20;
        freeKeyAmount = bound(freeKeyAmount, 1, keyAmount - lendAmount);

        startHoax(users.alice.account);
        uint256 keyId = _createKeys(keyAmount);
        /// Give Bob `freeKeyAmount` number of keys.
        keys.safeTransferFrom({
            from: users.alice.account,
            to: users.bob.account,
            id: keyId,
            value: freeKeyAmount,
            data: ""
        });
        /// Lend Bob `lendAmount` number of keys.
        keys.lendKeys({ lendee: users.bob.account, keyId: keyId, lendAmount: lendAmount, lendDuration: 3 days });
        vm.stopPrank();

        /// As Bob, ensure that only up to `freeKeyAmount` number of keys can be transferred.
        startHoax(users.bob.account);
        keys.safeTransferFrom({
            from: users.bob.account,
            to: users.eve.account,
            id: keyId,
            value: freeKeyAmount,
            data: ""
        });
        assertEq(keys.balanceOf({ account: users.eve.account, id: keyId }), freeKeyAmount);
        assertEq(keys.balanceOf({ account: users.bob.account, id: keyId }), lendAmount);

        /// At this point, Bob should only hold lended keys.
        for (uint256 amount = 1; amount <= lendAmount; amount++) {
            vm.expectRevert(IKeys.OverFreeKeyBalance.selector);
            keys.safeTransferFrom({
                from: users.bob.account,
                to: users.eve.account,
                id: keyId,
                value: amount,
                data: ""
            });
        }
    }

    function test_TransferKeys_ToLender_UpdatesTerms() public {
        uint256 keyAmount = keys.MAX_KEYS();
        uint256 lendAmount = 20;
        uint256 lendDuration = 3 days;

        startHoax(users.alice.account);
        uint256 keyId = _createKeys(keyAmount);
        keys.lendKeys({ lendee: users.bob.account, keyId: keyId, lendAmount: lendAmount, lendDuration: lendDuration });
        vm.stopPrank();

        IKeys.LendingTerms memory lendingTerms = keys.activeLends({ lendee: users.bob.account, keyId: keyId });
        assertEq(lendingTerms.lender, users.alice.account);
        assertEq(lendingTerms.amount, lendAmount);
        assertEq(lendingTerms.expiryTime, block.timestamp + lendDuration);

        IKeys.LendingTerms memory updatedTerms;

        /// Return 1 key at a time but 1 and ensure lending terms updates correctly.
        startHoax(users.bob.account);
        for (uint256 i = 1; i < lendAmount; i++) {
            keys.safeTransferFrom({ from: users.bob.account, to: users.alice.account, id: keyId, value: 1, data: "" });

            updatedTerms = keys.activeLends({ lendee: users.bob.account, keyId: keyId });
            assertEq(updatedTerms.lender, users.alice.account);
            assertEq(updatedTerms.amount, lendAmount - i);
            assertEq(updatedTerms.expiryTime, block.timestamp + lendDuration);
        }

        /// Return the final key and ensure the lending terms are fully cleared.
        keys.safeTransferFrom({ from: users.bob.account, to: users.alice.account, id: keyId, value: 1, data: "" });
        updatedTerms = keys.activeLends({ lendee: users.bob.account, keyId: keyId });
        assertEq(updatedTerms.lender, address(0));
        assertEq(updatedTerms.amount, 0);
        assertEq(updatedTerms.expiryTime, 0);
    }

    function test_ReclaimKeys_Fuzzed(uint256 lendAmount, uint256 lendDuration) public {
        uint256 keyAmount = keys.MAX_KEYS();
        lendAmount = bound(lendAmount, 1, keyAmount);
        lendDuration = bound(lendDuration, keys.MIN_LEND_DURATION(), keys.MAX_LEND_DURATION());

        startHoax(users.alice.account);
        uint256 keyId = _createKeys(keyAmount);
        keys.lendKeys({ lendee: users.bob.account, keyId: keyId, lendAmount: lendAmount, lendDuration: lendDuration });

        uint256 lendExpirationTime = keys.activeLends({ lendee: users.bob.account, keyId: keyId }).expiryTime;
        vm.warp(lendExpirationTime);

        keys.reclaimKeys({ lendee: users.bob.account, keyId: keyId });
        assertEq(keys.balanceOf({ account: users.bob.account, id: keyId }), 0);
        assertEq(keys.balanceOf({ account: users.alice.account, id: keyId }), keyAmount);

        IKeys.LendingTerms memory lendingTerms = keys.activeLends({ lendee: users.bob.account, keyId: keyId });
        assertEq(lendingTerms.lender, address(0));
        assertEq(lendingTerms.amount, 0);
        assertEq(lendingTerms.expiryTime, 0);
    }

    function testCannot_ReclaimKeys_KeysFrozen() public {
        uint256 keyAmount = keys.MAX_KEYS();

        startHoax(users.alice.account);
        uint256 keyId = _createKeys(keyAmount);
        keys.lendKeys({ lendee: users.bob.account, keyId: keyId, lendAmount: keyAmount, lendDuration: 3 days });
        vm.stopPrank();

        hoax(users.admin);
        keys.freezeKeys(keyId);

        uint256 lendExpirationTime = keys.activeLends({ lendee: users.bob.account, keyId: keyId }).expiryTime;
        vm.warp(lendExpirationTime);

        hoax(users.alice.account);
        vm.expectRevert(IKeys.KeysFrozen.selector);
        keys.reclaimKeys({ lendee: users.bob.account, keyId: keyId });
    }

    function testCannot_ReclaimKeys_NoActiveLend() public {
        uint256 keyAmount = keys.MAX_KEYS();

        startHoax(users.alice.account);
        uint256 keyId = _createKeys(keyAmount);

        vm.expectRevert(IKeys.NoActiveLend.selector);
        keys.reclaimKeys({ lendee: users.bob.account, keyId: keyId });
    }

    function testCannot_ReclaimKeys_LendStillActive() public {
        uint256 keyAmount = keys.MAX_KEYS();

        startHoax(users.alice.account);
        uint256 keyId = _createKeys(keyAmount);
        keys.lendKeys({ lendee: users.bob.account, keyId: keyId, lendAmount: keyAmount, lendDuration: 3 days });

        vm.expectRevert(IKeys.LendStillActive.selector);
        keys.reclaimKeys({ lendee: users.bob.account, keyId: keyId });
    }

    function test_RegisterVault(address newVault) public {
        keys.grantRoles({ user: users.admin, roles: keys.FACTORY_ROLE() });

        hoax(users.admin);
        keys.registerVault({ vault: newVault });
        assertTrue(keys.isRegistered(newVault));
    }

    function test_FreezeKeys_Fuzzed(uint256 keyId) public {
        keyId = bound(keyId, 1, type(uint256).max);

        hoax(users.admin);
        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: false, checkData: true });
        emit KeyFrozen({ admin: users.admin, keyId: keyId });
        keys.freezeKeys(keyId);

        assertTrue(keys.getKeyConfig(keyId).isFrozen);
    }

    /// TODO: Check why `0x2a07706473244BC757E10F2a9E86fB532828afe3` doesn't revert.
    function testCannot_FreezeKeys_Unauthorized_Fuzzed(address nonAdmin) public {
        vm.assume(nonAdmin != users.admin);

        hoax(nonAdmin);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        keys.freezeKeys(1);
    }

    function test_UnfreezeKeys(uint256 keyId) public {
        keyId = bound(keyId, 1, type(uint256).max);

        startHoax(users.admin);
        keys.freezeKeys(keyId);
        assertTrue(keys.getKeyConfig(keyId).isFrozen);

        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: false, checkData: true });
        emit KeyUnfrozen({ admin: users.admin, keyId: keyId });
        keys.unfreezeKeys(keyId);

        assertFalse(keys.getKeyConfig(keyId).isFrozen);
    }

    function testCannot_UnfreezeKeys_Unauthorized_Fuzzed(address nonAdmin) public {
        vm.assume(nonAdmin != users.admin);

        hoax(nonAdmin);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        keys.unfreezeKeys(1);
    }

    function test_SetKeyExchange(address newKeyExchange) public {
        keys.setKeyExchange({ _keyExchange: newKeyExchange });
        assertEq(keys.keyExchange(), newKeyExchange);
    }

    function testCannot_SetKeyExchange_Unauthorized_Fuzzed(address nonOwner) public {
        vm.assume(nonOwner != address(this));

        hoax(nonOwner);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        keys.setKeyExchange({ _keyExchange: nonOwner });
    }

    function testCannot_SafeTransferFrom_MissingApproval() public {
        startHoax(users.alice.account);
        uint256 keyId = _createKeys(keys.MAX_KEYS());
        vm.stopPrank();

        hoax(users.bob.account);
        vm.expectRevert();
        keys.safeTransferFrom({
            from: users.alice.account,
            to: users.bob.account,
            id: keyId,
            value: 1,
            data: ""
        });
    }

    function testCannot_SafeTransferFrom_KeysFrozen() public {
        startHoax(users.alice.account);
        uint256 keyId = _createKeys(keys.MAX_KEYS());
        vm.stopPrank();

        hoax(users.admin);
        keys.freezeKeys(keyId);

        hoax(users.alice.account);
        vm.expectRevert(IKeys.KeysFrozen.selector);
        keys.safeTransferFrom({
            from: users.alice.account,
            to: users.bob.account,
            id: keyId,
            value: 1,
            data: ""
        });
    }

    function testCannot_SafeTransferFrom_ZeroKeyTransfer() public {
        startHoax(users.alice.account);
        uint256 keyId = _createKeys(keys.MAX_KEYS());

        vm.expectRevert(IKeys.ZeroKeyTransfer.selector);
        keys.safeTransferFrom({
            from: users.alice.account,
            to: users.bob.account,
            id: keyId,
            value: 0,
            data: ""
        });
    }

    function test_SetURI_Fuzzed(string memory newURI) public {
        hoax(users.admin);
        keys.setURI(newURI);

        assertEq(keys.uri(0), newURI);
    }

    function testCannot_SetURI_Unauthorized_Fuzzed(address nonAdmin) public {
        vm.assume(nonAdmin != users.admin);
        
        hoax(nonAdmin);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        keys.setURI("");
    }

    /// Helper Function

    function _createKeys(uint256 amount) internal returns (uint256) {
        return keys.createKeys({ amount: amount, receiver: users.alice.account, vaultType: VaultType.SINGLE });
    }

}