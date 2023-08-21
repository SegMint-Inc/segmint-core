// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../Base.t.sol";

contract SegMintVaultManagerTest is Base {
    SegMintVault internal aliceVault;

    // function setUp() public override {
    //     super.setUp();

    //     /// KYC users.
    //     kycUsers();

    //     /// Since `factoryProxy` is a proxy, interface the proxy as the implementation contract.
    //     factory = SegMintFactory(address(factoryProxy));

    //     /// Grant `factory` the ability to approve vaults for `keys`.
    //     keys.grantRoles(address(factory), VAULT_MANAGER_ROLE);

    //     bytes memory signature = getCreateVaultSignature(users.alice, KYCRegistry.AccessType.RESTRICTED);

    //     /// Create a vault.
    //     hoax(users.alice, users.alice);
    //     factory.createVault(signature);

    //     /// Define `aliceVault`.
    //     address[] memory userVaults = factory.getVaults({ account: users.alice });
    //     aliceVault = SegMintVault(payable(userVaults[0]));

    //     vm.label({ account: address(aliceVault), newLabel: "Alice's Vault" });
    // }

    // /* Deployment Test */

    // function test_SegMintVault_Deployment() public {
    //     assertEq(aliceVault.owner(), users.alice);
    //     assertEq(address(aliceVault.keys()), address(keys));
    // }

    // /* `initialize()` Tests */

    // function test_Initialize() public {
    //     SegMintVault newVault = new SegMintVault();
    //     newVault.initialize({ owner_: users.alice, keys_: keys });

    //     assertEq(newVault.owner(), users.alice);
    //     assertEq(address(newVault.keys()), address(keys));
    // }

    // function testCannot_Initialize_Twice() public {
    //     hoax(users.eve, users.eve);
    //     vm.expectRevert("Initializable: contract is already initialized");
    //     aliceVault.initialize({ owner_: users.eve, keys_: ISegMintKeys(address(0)) });
    // }

    // /* `lockAssets()` Tests */

    // function test_LockAssets_ERC20() public {
    //     Vault.Asset[] memory vaultAssets = new Vault.Asset[](1);
    //     vaultAssets[0] = getERC20Asset();

    //     startHoax(users.alice, users.alice);
    //     erc20.approve(address(aliceVault), 100 ether);
    //     aliceVault.lockAssets({ assets: vaultAssets });
    //     vm.stopPrank();

    //     assertEq(erc20.balanceOf(address(aliceVault)), 100 ether);
    // }

    // function test_LockAssets_ERC721() public {
    //     Vault.Asset[] memory vaultAssets = new Vault.Asset[](1);
    //     vaultAssets[0] = getERC721Asset();

    //     startHoax(users.alice, users.alice);
    //     erc721.setApprovalForAll(address(aliceVault), true);
    //     aliceVault.lockAssets({ assets: vaultAssets });
    //     vm.stopPrank();

    //     assertEq(erc721.balanceOf(address(aliceVault)), 1);
    //     assertEq(erc721.ownerOf(ALICE_NFT_ID), address(aliceVault));
    // }

    // function test_LockAssets_ERC1155() public {
    //     Vault.Asset[] memory vaultAssets = new Vault.Asset[](1);
    //     vaultAssets[0] = getERC1155Asset();

    //     startHoax(users.alice, users.alice);
    //     erc1155.setApprovalForAll(address(aliceVault), true);
    //     aliceVault.lockAssets({ assets: vaultAssets });
    //     vm.stopPrank();

    //     assertEq(erc1155.balanceOf(address(aliceVault), ERC1155_TOKEN_ID), 1);
    // }

    // function test_LockAssets_Mixed() public { }

    // function test_LockAssets_Fuzzed() public { }

    // function testCannot_LockAssets_Unauthorized() public {
    //     Vault.Asset[] memory vaultAssets = new Vault.Asset[](1);

    //     hoax(users.eve, users.eve);
    //     vm.expectRevert(Errors.Unauthorized.selector);
    //     aliceVault.lockAssets({ assets: vaultAssets });
    // }

    // function testCannot_LockAssets_ZeroLengthArray() public {
    //     Vault.Asset[] memory vaultAssets = new Vault.Asset[](0);

    //     hoax(users.alice, users.alice);
    //     vm.expectRevert(Errors.ZeroLengthArray.selector);
    //     aliceVault.lockAssets({ assets: vaultAssets });
    // }

    // function testCannot_LockAssets_OverMovementLimit() public {
    //     Vault.Asset[] memory vaultAssets = new Vault.Asset[](21);

    //     hoax(users.alice, users.alice);
    //     vm.expectRevert(Errors.OverMovementLimit.selector);
    //     aliceVault.lockAssets({ assets: vaultAssets });
    // }

    // function testCannot_LockAssets_KeyBinded() public {
    //     Vault.Asset[] memory vaultAssets = new Vault.Asset[](1);

    //     startHoax(users.alice, users.alice);
    //     aliceVault.bindKeys({ amount: 5 });

    //     vm.expectRevert(Errors.KeyBinded.selector);
    //     aliceVault.lockAssets({ assets: vaultAssets });
    // }

    // /* `unlockAssets()` Tests */

    // function test_UnlockAssets_ERC20() public lockERC20 {
    //     Vault.Asset[] memory vaultAssets = new Vault.Asset[](1);
    //     vaultAssets[0] = getERC20Asset();

    //     uint256 initialBalance = erc20.balanceOf(users.alice);
    //     hoax(users.alice, users.alice);
    //     aliceVault.unlockAssets({ assets: vaultAssets, receiver: users.alice });
    //     uint256 updatedBalance = erc20.balanceOf(users.alice);

    //     assertEq(erc20.balanceOf(address(aliceVault)), 0 ether);
    //     assertEq(updatedBalance, initialBalance + vaultAssets[0].amount);
    // }

    // function test_UnlockAssets_ERC721() public lockERC721 {
    //     Vault.Asset[] memory vaultAssets = new Vault.Asset[](1);
    //     vaultAssets[0] = getERC721Asset();

    //     hoax(users.alice, users.alice);
    //     aliceVault.unlockAssets({ assets: vaultAssets, receiver: users.alice });

    //     assertEq(erc721.ownerOf(vaultAssets[0].identifier), users.alice);
    // }

    // function test_UnlockAssets_ERC1155() public lockERC1155 {
    //     Vault.Asset[] memory vaultAssets = new Vault.Asset[](1);
    //     vaultAssets[0] = getERC1155Asset();

    //     hoax(users.alice, users.alice);
    //     aliceVault.unlockAssets({ assets: vaultAssets, receiver: users.alice });

    //     assertEq(erc1155.balanceOf(users.alice, vaultAssets[0].identifier), vaultAssets[0].amount);
    // }

    // function test_UnlockAssets_Mixed() public lockMixed {
    //     Vault.Asset[] memory vaultAssets = getMixedAssets();

    //     uint256 initialBalance = erc20.balanceOf(users.alice);
    //     hoax(users.alice, users.alice);
    //     aliceVault.unlockAssets({ assets: vaultAssets, receiver: users.alice });
    //     uint256 updatedBalance = erc20.balanceOf(users.alice);

    //     assertEq(updatedBalance, initialBalance + vaultAssets[0].amount);
    //     assertEq(erc721.ownerOf(vaultAssets[1].identifier), users.alice);
    //     assertEq(erc1155.balanceOf(users.alice, vaultAssets[2].identifier), vaultAssets[2].amount);
    // }

    // function test_UnlockAssets_Mixed_AsKeyHolder() public { }

    // function test_UnlockAssets_Fuzzed() public { }

    // function testCannot_UnlockAssets_ZeroLengthArray() public {
    //     Vault.Asset[] memory vaultAssets = new Vault.Asset[](0);

    //     hoax(users.alice, users.alice);
    //     vm.expectRevert(Errors.ZeroLengthArray.selector);
    //     aliceVault.unlockAssets({ assets: vaultAssets, receiver: users.alice });
    // }

    // function testCannot_UnlockAssets_OverMovementLimit() public {
    //     Vault.Asset[] memory vaultAssets = new Vault.Asset[](21);

    //     hoax(users.alice, users.alice);
    //     vm.expectRevert(Errors.OverMovementLimit.selector);
    //     aliceVault.unlockAssets({ assets: vaultAssets, receiver: users.alice });
    // }

    // function testCannot_UnlockAssets_Unauthorized() public {
    //     Vault.Asset[] memory vaultAssets = new Vault.Asset[](1);

    //     hoax(users.eve, users.eve);
    //     vm.expectRevert(Errors.Unauthorized.selector);
    //     aliceVault.unlockAssets({ assets: vaultAssets, receiver: users.alice });
    // }

    // function testCannot_UnlockAssets_InsufficientKeys() public lockMixed {
    //     Vault.Asset[] memory vaultAssets = getMixedAssets();

    //     startHoax(users.alice, users.alice);
    //     aliceVault.bindKeys({ amount: 5 });
    //     keys.safeTransferFrom({ from: users.alice, to: users.bob, id: 1, amount: 1, data: "" });

    //     vm.expectRevert(Errors.InsufficientKeys.selector);
    //     aliceVault.unlockAssets({ assets: vaultAssets, receiver: users.alice });
    //     vm.stopPrank();
    // }

    // /* `unlockEther()` Tests */

    // function test_UnlockEther() public {
    //     uint256 etherAmount = 10 ether;
    //     vm.deal(address(aliceVault), etherAmount);

    //     hoax(users.alice, users.alice, 0 ether);
    //     aliceVault.unlockEther({ amount: etherAmount, receiver: users.alice });

    //     assertEq(address(aliceVault).balance, 0 ether);
    //     assertEq(users.alice.balance, etherAmount);
    // }

    // function test_UnlockEther_AsKeyHolder() public {
    //     uint256 etherAmount = 10 ether;
    //     vm.deal(address(aliceVault), etherAmount);

    //     startHoax(users.alice, users.alice);
    //     aliceVault.bindKeys({ amount: 5 });
    //     keys.safeTransferFrom({ from: users.alice, to: users.bob, id: 1, amount: 5, data: "" });
    //     vm.stopPrank();

    //     hoax(users.bob, users.bob, 0 ether);
    //     aliceVault.unlockEther({ amount: etherAmount, receiver: users.bob });

    //     assertEq(address(aliceVault).balance, 0 ether);
    //     assertEq(users.bob.balance, etherAmount);
    // }

    // function testCannot_UnlockEther_InsufficientKeys() public {
    //     uint256 etherAmount = 10 ether;
    //     vm.deal(address(aliceVault), etherAmount);

    //     startHoax(users.alice, users.alice);
    //     aliceVault.bindKeys({ amount: 5 });
    //     keys.safeTransferFrom({ from: users.alice, to: users.bob, id: 1, amount: 3, data: "" });
    //     vm.stopPrank();

    //     hoax(users.bob, users.bob, 0 ether);
    //     vm.expectRevert(Errors.InsufficientKeys.selector);
    //     aliceVault.unlockEther({ amount: etherAmount, receiver: users.bob });
    // }

    // function testCannot_UnlockEther_Unauthorized() public {
    //     uint256 etherAmount = 10 ether;
    //     vm.deal(address(aliceVault), etherAmount);

    //     hoax(users.eve, users.eve);
    //     vm.expectRevert(Errors.Unauthorized.selector);
    //     aliceVault.unlockEther({ amount: etherAmount, receiver: users.eve });
    // }

    // function testCannot_UnlockEther_TransferFailed() public {
    //     uint256 etherAmount = 10 ether;

    //     vm.deal(address(aliceVault), etherAmount);
    //     vm.mockCallRevert({ callee: users.alice, data: "", revertData: "" });

    //     hoax(users.alice, users.alice);
    //     vm.expectRevert(Errors.TransferFailed.selector);
    //     aliceVault.unlockEther({ amount: etherAmount, receiver: users.alice });
    // }

    // /* `bindKeys()` Tests */

    // function test_BindKeys() public lockMixed {
    //     hoax(users.alice, users.alice);
    //     vm.expectEmit({
    //         checkTopic1: true,
    //         checkTopic2: false,
    //         checkTopic3: false,
    //         checkData: true,
    //         emitter: address(aliceVault)
    //     });
    //     emit KeysCreated({ vault: address(aliceVault), keyId: 1, amount: 5 });
    //     aliceVault.bindKeys({ amount: 5 });

    //     (bool binded, uint256 keyId, uint256 amount) = aliceVault.keyBindings();
    //     assertTrue(binded);
    //     assertEq(keyId, 1);
    //     assertEq(amount, 5);
    // }

    // function testCannot_BindKeys_Unauthorized() public {
    //     hoax(users.eve, users.eve);
    //     vm.expectRevert(Errors.Unauthorized.selector);
    //     aliceVault.bindKeys({ amount: 5 });
    // }

    // function testCannot_BindKeys_KeyBinded() public {
    //     startHoax(users.alice, users.alice);
    //     aliceVault.bindKeys({ amount: 5 });

    //     vm.expectRevert(Errors.KeyBinded.selector);
    //     aliceVault.bindKeys({ amount: 5 });
    //     vm.stopPrank();
    // }

    // function testCannot_BindKeys_InvalidKeyAmount() public {
    //     startHoax(users.alice, users.alice);
    //     vm.expectRevert(Errors.InvalidKeyAmount.selector);
    //     aliceVault.bindKeys({ amount: 0 });
    // }

    // /* `unbindKeys()` Tests */

    // function test_UnbindKeys() public {
    //     startHoax(users.alice, users.alice);
    //     aliceVault.bindKeys({ amount: 5 });

    //     vm.expectEmit({
    //         checkTopic1: true,
    //         checkTopic2: false,
    //         checkTopic3: false,
    //         checkData: true,
    //         emitter: address(aliceVault)
    //     });
    //     emit KeysBurned({ vault: address(aliceVault), keyId: 1, amount: 5 });
    //     aliceVault.unbindKeys();

    //     (bool binded, uint256 keyId, uint256 amount) = aliceVault.keyBindings();
    //     assertFalse(binded);
    //     assertEq(keyId, 0);
    //     assertEq(amount, 0);
    // }

    // function testCannot_UnbindKeys_NotKeyBinded() public {
    //     startHoax(users.alice, users.alice);
    //     vm.expectRevert(Errors.NotKeyBinded.selector);
    //     aliceVault.unbindKeys();
    // }

    // function testCannot_UnbindKeys_InsufficientKeys() public {
    //     startHoax(users.alice, users.alice);

    //     aliceVault.bindKeys({ amount: 5 });
    //     keys.safeTransferFrom({ from: users.alice, to: users.bob, id: 1, amount: 3, data: "" });

    //     vm.expectRevert(Errors.InsufficientKeys.selector);
    //     aliceVault.unbindKeys();
    // }

    // /* `receive()` Test */

    // function test_Receive() public {
    //     uint256 etherAmount = 10 ether;

    //     hoax(users.alice, users.alice);
    //     (bool success,) = address(aliceVault).call{ value: etherAmount }("");

    //     assertTrue(success);
    //     assertEq(address(aliceVault).balance, etherAmount);
    // }

    // /* Helpers */

    // modifier lockERC20() {
    //     Vault.Asset[] memory vaultAssets = new Vault.Asset[](1);
    //     vaultAssets[0] = getERC20Asset();

    //     startHoax(users.alice, users.alice);
    //     erc20.approve(address(aliceVault), vaultAssets[0].amount);
    //     aliceVault.lockAssets({ assets: vaultAssets });
    //     vm.stopPrank();

    //     _;
    // }

    // modifier lockERC721() {
    //     Vault.Asset[] memory vaultAssets = new Vault.Asset[](1);
    //     vaultAssets[0] = getERC721Asset();

    //     startHoax(users.alice, users.alice);
    //     erc721.setApprovalForAll(address(aliceVault), true);
    //     aliceVault.lockAssets({ assets: vaultAssets });
    //     vm.stopPrank();

    //     _;
    // }

    // modifier lockERC1155() {
    //     Vault.Asset[] memory vaultAssets = new Vault.Asset[](1);
    //     vaultAssets[0] = getERC1155Asset();

    //     startHoax(users.alice, users.alice);
    //     erc1155.setApprovalForAll(address(aliceVault), true);
    //     aliceVault.lockAssets({ assets: vaultAssets });
    //     vm.stopPrank();

    //     _;
    // }

    // modifier lockMixed() {
    //     Vault.Asset[] memory vaultAssets = getMixedAssets();

    //     startHoax(users.alice, users.alice);
    //     erc20.approve(address(aliceVault), vaultAssets[0].amount);
    //     erc721.setApprovalForAll(address(aliceVault), true);
    //     erc1155.setApprovalForAll(address(aliceVault), true);
    //     aliceVault.lockAssets({ assets: vaultAssets });
    //     vm.stopPrank();

    //     _;
    // }

    // function getERC20Asset() internal view returns (Vault.Asset memory) {
    //     return Vault.Asset({ assetType: AssetType.ERC20, token: address(erc20), identifier: 0, amount: 100 ether });
    // }

    // function getERC721Asset() internal view returns (Vault.Asset memory) {
    //     return Vault.Asset({ assetType: AssetType.ERC721, token: address(erc721), identifier: ALICE_NFT_ID, amount: 1 });
    // }

    // function getERC1155Asset() internal view returns (Vault.Asset memory) {
    //     return Vault.Asset({
    //         assetType: AssetType.ERC1155,
    //         token: address(erc1155),
    //         identifier: ERC1155_TOKEN_ID,
    //         amount: 1
    //     });
    // }

    // function getMixedAssets() internal view returns (Vault.Asset[] memory) {
    //     Vault.Asset[] memory vaultAssets = new Vault.Asset[](3);
    //     vaultAssets[0] = getERC20Asset();
    //     vaultAssets[1] = getERC721Asset();
    //     vaultAssets[2] = getERC1155Asset();

    //     return vaultAssets;
    // }
}
