// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./BaseTest.sol";

contract ServiceFactoryTest is BaseTest {
    MAVault public vault;

    /// Deposit assets into the multi-asset vault.
    modifier depositAssets() {
        startHoax(users.alice.account);

        mockERC20.transfer(address(vault), ERC20_BALANCE);
        mockERC721.safeTransferFrom(users.alice.account, address(vault), ALICE_721_ID);
        mockERC1155.safeTransferFrom(users.alice.account, address(vault), ERC1155_ID, 1, "");

        vm.stopPrank();

        _;
    }

    /// Deposits assets then binds the maximum number of keys to a vault.
    modifier depositAssetsAndBind() {
        startHoax(users.alice.account);

        mockERC20.transfer(address(vault), ERC20_BALANCE);
        mockERC721.safeTransferFrom(users.alice.account, address(vault), ALICE_721_ID);
        mockERC1155.safeTransferFrom(users.alice.account, address(vault), ERC1155_ID, 1, "");

        vault.bindKeys({ keyAmount: keys.MAX_KEYS() });

        vm.stopPrank();

        _;
    }

    function setUp() public override {
        super.setUp();
        kycUsers(); // KYC both Alice and Bob.

        /// Interface the proxy contract with the implementation so that calls are delegated correctly.
        serviceFactory = ServiceFactory(address(serviceFactoryProxy));

        /// Create a multi-asset vault for Alice.
        startHoax(users.alice.account);
        serviceFactory.createMultiAssetVault({
            signature: getVaultCreationSignature(users.alice.account, 0, VaultType.MULTI)
        });
        vm.stopPrank();

        vault = MAVault(payable(serviceFactory.getMultiAssetVaults({ account: users.alice.account })[0]));
    }

    function test_UnlockAssets() public depositAssets {
        /// Ensure vault holds the following assets.
        assertEq(mockERC20.balanceOf(address(vault)), ERC20_BALANCE);
        assertEq(mockERC721.balanceOf(address(vault)), 1);
        assertEq(mockERC721.ownerOf(0), address(vault));
        assertEq(mockERC1155.balanceOf(address(vault), 0), 1);

        Asset[] memory assets = getAssets();

        hoax(users.alice.account);
        vault.unlockAssets({ assets: assets, receiver: users.alice.account });
    }

    function testCannot_UnlockAssets_ZeroAssetAmount() public {
        Asset[] memory assets = new Asset[](0);

        hoax(users.alice.account);
        vm.expectRevert(IMAVault.ZeroAssetAmount.selector);
        vault.unlockAssets({ assets: assets, receiver: users.alice.account });
    }

    function testCannot_UnlockAssets_Unauthorized(address nonOwner) public depositAssets {
        vm.assume(nonOwner != users.alice.account);

        Asset[] memory assets = getAssets();

        hoax(nonOwner);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        vault.unlockAssets({ assets: assets, receiver: nonOwner });
    }

    function testCannot_UnlockAssets_NoneAssetType() public {
        Asset[] memory assets = getAssets();
        assets[0].class = AssetClass.NONE;

        hoax(users.alice.account);
        vm.expectRevert(IMAVault.NoneAssetType.selector);
        vault.unlockAssets({ assets: assets, receiver: users.alice.account });
    }

    function test_UnlockAssets_AsKeyHolder() public depositAssetsAndBind {
        uint256 keyId = vault.boundKeyId();
        uint256 keySupply = vault.getKeyConfig().supply;

        /// Transfer keys to someone other than the original owner.
        hoax(users.alice.account);
        keys.safeTransferFrom(users.alice.account, users.bob.account, keyId, keySupply, "");

        Asset[] memory assets = getAssets();

        hoax(users.bob.account);
        vault.unlockAssets({ assets: assets, receiver: users.bob.account });
    }

    function testCannot_UnlockAssets_AsOwner_InsufficientKeys() public depositAssetsAndBind {
        uint256 keyId = vault.boundKeyId();
        uint256 keySupply = vault.getKeyConfig().supply;

        /// Transfer keys to someone other than the original owner.
        hoax(users.alice.account);
        keys.safeTransferFrom(users.alice.account, users.bob.account, keyId, keySupply, "");

        Asset[] memory assets = getAssets();

        hoax(users.alice.account);
        vm.expectRevert(IMAVault.InsufficientKeys.selector);
        vault.unlockAssets({ assets: assets, receiver: users.alice.account });
    }

    function test_UnlockNativeToken_Fuzzed(uint256 amount) public {
        amount = bound(amount, 1 wei, 100 ether);

        deal({ to: address(vault), give: amount });
        assertEq(address(vault).balance, amount);

        hoax(users.alice.account, 0 ether);
        vault.unlockNativeToken({ amount: amount, receiver: users.alice.account });
        assertEq(users.alice.account.balance, amount);
    }

    function testCannot_UnlockNativeToken_Unauthorized_Fuzzed(address nonOwner) public {
        vm.assume(nonOwner != users.alice.account);

        uint256 amount = 1 ether;
        deal({ to: address(vault), give: amount });
        assertEq(address(vault).balance, amount);

        hoax(nonOwner);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        vault.unlockNativeToken({ amount: amount, receiver: nonOwner });
    }

    function testCannot_UnlockNativeToken_NativeTokenUnlockFailed() public {
        uint256 amount = 1 ether;
        deal({ to: address(vault), give: amount });
        assertEq(address(vault).balance, amount);

        vm.mockCallRevert({ callee: users.alice.account, data: "", revertData: "" });

        hoax(users.alice.account);
        vm.expectRevert(IMAVault.NativeTokenUnlockFailed.selector);
        vault.unlockNativeToken({ amount: amount, receiver: users.alice.account });
    }

    function test_UnlockNativeToken_AsKeyHolder_Fuzzed(uint256 amount) public depositAssetsAndBind {
        amount = bound(amount, 1 wei, 100 ether);

        deal({ to: address(vault), give: amount });
        assertEq(address(vault).balance, amount);

        uint256 keyId = vault.boundKeyId();
        uint256 keySupply = vault.getKeyConfig().supply;

        /// Transfer keys to someone other than the original owner.
        hoax(users.alice.account);
        keys.safeTransferFrom(users.alice.account, users.bob.account, keyId, keySupply, "");

        hoax(users.bob.account, 0 ether);
        vault.unlockNativeToken({ amount: amount, receiver: users.bob.account });
        assertEq(users.bob.account.balance, amount);
    }

    function testCannot_UnlockNativeToken_AsOwner_InsufficientKeys() public depositAssetsAndBind {
        uint256 keyId = vault.boundKeyId();
        uint256 keySupply = vault.getKeyConfig().supply;

        /// Transfer keys to someone other than the original owner.
        hoax(users.alice.account);
        keys.safeTransferFrom(users.alice.account, users.bob.account, keyId, keySupply, "");

        hoax(users.alice.account);
        vm.expectRevert(IMAVault.InsufficientKeys.selector);
        vault.unlockNativeToken({ amount: 0, receiver: users.alice.account });
    }

    function test_BindKeys() public depositAssets {
        uint256 keyAmount = keys.MAX_KEYS();

        hoax(users.alice.account);
        vault.bindKeys({ keyAmount: keyAmount });

        uint256 keyId = vault.boundKeyId();
        assertTrue(keyId != 0);
        assertEq(keys.keysCreated(), 1);

        KeyConfig memory vaultKeyConfig = vault.getKeyConfig();
        assertEq(vaultKeyConfig.creator, users.alice.account);
        assertEq(vaultKeyConfig.vaultType, VaultType.MULTI);
        assertFalse(vaultKeyConfig.isFrozen);
        assertFalse(vaultKeyConfig.isBurned);
        assertEq(vaultKeyConfig.supply, keyAmount);

        /// Even though the vault pulls the key config from the key contract, we should
        /// guarantee that the values match.
        KeyConfig memory keyConfig = keys.getKeyConfig(keyId);
        assertEq(keyConfig.creator, vaultKeyConfig.creator);
        assertEq(keyConfig.vaultType, vaultKeyConfig.vaultType);
        assertEq(keyConfig.isFrozen, vaultKeyConfig.isFrozen);
        assertEq(keyConfig.isFrozen, vaultKeyConfig.isBurned);
        assertEq(keyConfig.supply, vaultKeyConfig.supply);
    }

    function testCannot_BindKeys_Unauthorized(address nonOwner) public {
        vm.assume(nonOwner != users.alice.account);

        uint256 keyAmount = keys.MAX_KEYS();

        hoax(nonOwner);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        vault.bindKeys({ keyAmount: keyAmount });
    }

    function testCannot_BindKeys_KeysAlreadyBinded() public {
        uint256 keyAmount = keys.MAX_KEYS();

        startHoax(users.alice.account);
        vault.bindKeys({ keyAmount: keyAmount });
        vm.expectRevert(IMAVault.KeysAlreadyBinded.selector);
        vault.bindKeys({ keyAmount: keyAmount });
    }

    function test_UnbindKeys() public depositAssetsAndBind {
        uint256 preBurnKeyId = vault.boundKeyId();

        hoax(users.alice.account);
        vault.unbindKeys();

        uint256 newKeyId = vault.boundKeyId();
        assertEq(newKeyId, 0);

        KeyConfig memory keyConfig = keys.getKeyConfig(preBurnKeyId);
        assertEq(keyConfig.creator, users.alice.account);
        assertEq(keyConfig.vaultType, VaultType.MULTI);
        assertFalse(keyConfig.isFrozen);
        assertTrue(keyConfig.isBurned);
        assertEq(keyConfig.supply, keys.MAX_KEYS());
    }

    function testCannot_UnbindKeys_NoKeysBinded() public {
        hoax(users.alice.account);
        vm.expectRevert(IMAVault.NoKeysBinded.selector);
        vault.unbindKeys();
    }

    function testCannot_UnbindKeys_InsufficientKeys() public depositAssetsAndBind {
        hoax(users.eve.account);
        vm.expectRevert(IMAVault.InsufficientKeys.selector);
        vault.unbindKeys();
    }

}
