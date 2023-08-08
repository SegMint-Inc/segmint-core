// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../Base.t.sol";

contract SegMintVaultManagerTest is Base {
    SegMintVaultSingle internal aliceVault;

    modifier bindKeysToVault() {
        hoax(users.alice, users.alice);
        aliceVault.bindKeys({ amount: 5 });
        _;
    }

    function setUp() public override {
        super.setUp();

        /// KYC users.
        kycUsers();

        /// Since `vaultManagerProxy` is a proxy, interface the proxy as the implementation contract.
        vaultManager = SegMintVaultManager(address(vaultManagerProxy));

        /// Grant `vaultManager` the ability to approve vaults for `keys`.
        keys.grantRoles(address(vaultManager), VAULT_MANAGER_ROLE);

        /// Get {SegMintVaultManager.createVaultSingle} signature.
        bytes memory signature = getCreateVaultSingleSignature(users.alice, KYCRegistry.AccessType.RESTRICTED);

        /// Define the asset to be locked.
        VaultSingle.Asset memory asset = getSingleLockAsset();

        /// Approve vault manager for asset movement and create a new single vault.
        startHoax(users.alice, users.alice);
        erc721.setApprovalForAll(address(vaultManager), true);
        vaultManager.createVaultSingle(signature, asset);
        vm.stopPrank();

        /// Define `aliceVault`.
        address[] memory userVaults = vaultManager.getSingleVaults({ account: users.alice });
        aliceVault = SegMintVaultSingle(userVaults[0]);

        vm.label({ account: address(aliceVault), newLabel: "Alice's Single Vault" });
    }

    /* Deployment Test */

    function test_SegMintVaultSingle_Deployment() public {
        assertEq(aliceVault.owner(), users.alice);
        assertEq(address(aliceVault.keys()), address(keys));

        (bool isBinded, uint256 keyId, uint256 amount) = aliceVault.keyBindings();
        assertFalse(isBinded);
        assertEq(keyId, 0);
        assertEq(amount, 0);

        (VaultSingle.SingleClass class, address tokenAddress, uint256 tokenId, uint256 tokenAmount) = aliceVault.asset();
        assertEq(uint256(class), uint256(VaultSingle.SingleClass.ERC_721));
        assertEq(tokenAddress, address(erc721));
        assertEq(tokenId, ALICE_NFT_ID);
        assertEq(tokenAmount, 1);

        assertEq(erc721.ownerOf(ALICE_NFT_ID), address(aliceVault));
        assertEq(erc721.balanceOf(address(aliceVault)), 1);
    }

    /* `initialize()` Tests */

    function test_Initialize_AsExpected() public {
        SegMintVaultSingle newVault = new SegMintVaultSingle();
        VaultSingle.Asset memory asset = getSingleLockAsset();

        hoax(users.alice, users.alice);
        newVault.initialize({ owner_: users.alice, keys_: keys, asset_: asset });

        assertEq(newVault.owner(), users.alice);
        assertEq(address(newVault.keys()), address(keys));

        (VaultSingle.SingleClass class, address tokenAddress, uint256 tokenId, uint256 tokenAmount) = newVault.asset();
        assertEq(uint256(class), uint256(VaultSingle.SingleClass.ERC_721));
        assertEq(tokenAddress, address(erc721));
        assertEq(tokenId, ALICE_NFT_ID);
        assertEq(tokenAmount, 1);
    }

    function testCannot_Initialize_Twice() public {
        VaultSingle.Asset memory asset = getSingleLockAsset();

        hoax(users.eve, users.eve);
        vm.expectRevert("Initializable: contract is already initialized");
        aliceVault.initialize({ owner_: users.eve, keys_: keys, asset_: asset });
    }

    /* `unlockAsset()` Tests */

    function test_UnlockAsset_ToSelf_NoKeys() public {
        hoax(users.alice, users.alice);
        aliceVault.unlockAsset({ receiver: users.alice });

        (VaultSingle.SingleClass class, address tokenAddress, uint256 tokenId, uint256 tokenAmount) = aliceVault.asset();
        assertEq(uint256(class), uint256(VaultSingle.SingleClass.NONE));
        assertEq(tokenAddress, address(0));
        assertEq(tokenId, 0);
        assertEq(tokenAmount, 0);

        assertEq(erc721.ownerOf(ALICE_NFT_ID), users.alice);
        assertEq(erc721.balanceOf(address(aliceVault)), 0);
    }

    function test_UnlockAsset_ToUser_NoKeys() public {
        hoax(users.alice, users.alice);
        aliceVault.unlockAsset({ receiver: users.bob });

        (VaultSingle.SingleClass class, address tokenAddress, uint256 tokenId, uint256 tokenAmount) = aliceVault.asset();
        assertEq(uint256(class), uint256(VaultSingle.SingleClass.NONE));
        assertEq(tokenAddress, address(0));
        assertEq(tokenId, 0);
        assertEq(tokenAmount, 0);

        assertEq(erc721.ownerOf(ALICE_NFT_ID), users.bob);
        assertEq(erc721.balanceOf(address(aliceVault)), 0);
    }

    function test_UnlockAsset_ToSelf_WithKeys() public {
        startHoax(users.alice, users.alice);
        aliceVault.bindKeys({ amount: 5 });
        aliceVault.unlockAsset({ receiver: users.alice });
        vm.stopPrank();

        (VaultSingle.SingleClass class, address tokenAddress, uint256 tokenId, uint256 tokenAmount) = aliceVault.asset();
        assertEq(uint256(class), uint256(VaultSingle.SingleClass.NONE));
        assertEq(tokenAddress, address(0));
        assertEq(tokenId, 0);
        assertEq(tokenAmount, 0);

        assertEq(erc721.ownerOf(ALICE_NFT_ID), users.alice);
        assertEq(erc721.balanceOf(address(aliceVault)), 0);
    }

    function test_UnlockAsset_ToUser_WithKeys() public {
        startHoax(users.alice, users.alice);
        aliceVault.bindKeys({ amount: 5 });
        aliceVault.unlockAsset({ receiver: users.bob });
        vm.stopPrank();

        (VaultSingle.SingleClass class, address tokenAddress, uint256 tokenId, uint256 tokenAmount) = aliceVault.asset();
        assertEq(uint256(class), uint256(VaultSingle.SingleClass.NONE));
        assertEq(tokenAddress, address(0));
        assertEq(tokenId, 0);
        assertEq(tokenAmount, 0);

        assertEq(erc721.ownerOf(ALICE_NFT_ID), users.bob);
        assertEq(erc721.balanceOf(address(aliceVault)), 0);
    }

    function testCannot_UnlockAsset_NoAssetLocked() public {
        startHoax(users.alice, users.alice);
        aliceVault.unlockAsset({ receiver: users.alice });

        vm.expectRevert(Errors.NoAssetLocked.selector);
        aliceVault.unlockAsset({ receiver: users.alice });
    }

    function testCannot_UnlockAsset_Unauthorized() public {
        hoax(users.eve, users.eve);
        vm.expectRevert(Errors.Unauthorized.selector);
        aliceVault.unlockAsset({ receiver: users.eve });
    }

    function testCannot_UnlockAsset_InsufficientKeys() public {
        startHoax(users.alice, users.alice);
        aliceVault.bindKeys({ amount: 5 });
        keys.safeTransferFrom({ from: users.alice, to: users.bob, id: 1, amount: 1, data: "" });

        vm.expectRevert(Errors.InsufficientKeys.selector);
        aliceVault.unlockAsset({ receiver: users.alice });
    }

    /* `bindKeys()` Tests */

    function test_BindKeys() public {
        uint256 keyAmount = 5;

        hoax(users.alice, users.alice);
        vm.expectEmit({
            checkTopic1: true,
            checkTopic2: true,
            checkTopic3: true,
            checkData: true,
            emitter: address(aliceVault)
        });
        emit KeysCreated({ vault: address(aliceVault), keyId: 1, amount: keyAmount });
        aliceVault.bindKeys({ amount: keyAmount });

        (bool isBinded, uint256 keyId, uint256 amount) = aliceVault.keyBindings();
        assertTrue(isBinded);
        assertEq(keyId, 1);
        assertEq(amount, keyAmount);
    }

    function test_BindKeys_Fuzzed(uint256 keyAmount) public {
        keyAmount = bound(keyAmount, 1, type(uint8).max);

        hoax(users.alice, users.alice);
        vm.expectEmit({
            checkTopic1: true,
            checkTopic2: true,
            checkTopic3: true,
            checkData: true,
            emitter: address(aliceVault)
        });
        emit KeysCreated({ vault: address(aliceVault), keyId: 1, amount: keyAmount });
        aliceVault.bindKeys({ amount: keyAmount });

        (bool isBinded, uint256 keyId, uint256 amount) = aliceVault.keyBindings();
        assertTrue(isBinded);
        assertEq(keyId, 1);
        assertEq(amount, keyAmount);
    }

    function testCannot_BindKeys_Unauthorized() public {
        hoax(users.eve, users.eve);
        vm.expectRevert(Errors.Unauthorized.selector);
        aliceVault.bindKeys({ amount: 100 });
    }

    function testCannot_BindKeys_NoAssetLocked() public {
        startHoax(users.alice, users.alice);
        aliceVault.unlockAsset({ receiver: users.alice });

        vm.expectRevert(Errors.NoAssetLocked.selector);
        aliceVault.bindKeys({ amount: 5 });
    }

    function testCannot_BindKeys_InvalidKeyAmount() public {
        hoax(users.alice, users.alice);
        vm.expectRevert(Errors.InvalidKeyAmount.selector);
        aliceVault.bindKeys({ amount: 0 });
    }

    /* `unbindKeys()` Tests */

    function test_UnbindKeys() public bindKeysToVault {
        hoax(users.alice, users.alice);
        vm.expectEmit({
            checkTopic1: true,
            checkTopic2: true,
            checkTopic3: true,
            checkData: true,
            emitter: address(aliceVault)
        });
        emit KeysBurned({ vault: address(aliceVault), keyId: 1, amount: 5 });
        aliceVault.unbindKeys();

        (bool isBinded, uint256 keyId, uint256 amount) = aliceVault.keyBindings();
        assertFalse(isBinded);
        assertEq(keyId, 0);
        assertEq(amount, 0);
    }

    function testCannot_UnbindKeys_NotKeyBinded() public {
        hoax(users.alice, users.alice);
        vm.expectRevert(Errors.NotKeyBinded.selector);
        aliceVault.unbindKeys();
    }

    function testCannot_UnbindKeys_InsufficientKeys() public bindKeysToVault {
        startHoax(users.alice, users.alice);
        keys.safeTransferFrom({ from: users.alice, to: users.bob, id: 1, amount: 1, data: "" });

        vm.expectRevert(Errors.InsufficientKeys.selector);
        aliceVault.unbindKeys();
    }

    /* Helper Functions */

    function getSingleLockAsset() internal view returns (VaultSingle.Asset memory) {
        return VaultSingle.Asset({
            class: VaultSingle.SingleClass.ERC_721,
            addr: address(erc721),
            tokenId: ALICE_NFT_ID,
            amount: 1
        });
    }
}
