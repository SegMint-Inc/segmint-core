// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./BaseTest.sol";

contract MAVaultTest is BaseTest {
    MAVault public vault;
    uint256 public keySupply = 100;

    /// Deposit assets into the multi-asset vault.
    modifier depositAssets() {
        startHoax(users.alice.account);

        mockERC20.transfer(address(vault), ERC20_BALANCE);
        mockERC721.safeTransferFrom(users.alice.account, address(vault), ALICE_721_ID);
        mockERC1155.safeTransferFrom(users.alice.account, address(vault), ERC1155_ID, 1, "");

        vm.stopPrank();

        _;
    }

    function setUp() public override {
        super.setUp();
        kycUsers(); // KYC both Alice and Bob.

        /// Create a multi-asset vault for Alice.
        (uint256 maNonce,) = vaultFactory.getNonces(users.alice.account);
        bytes memory signature = getVaultCreationSignature(users.alice.account, maNonce, VaultType.MULTI);

        hoax(users.alice.account);
        vaultFactory.createMultiAssetVault({ keyAmount: keySupply, delegateAssets: false, signature: signature });

        vault = MAVault(payable(vaultFactory.getMultiAssetVaults({ account: users.alice.account })[0]));
    }

    function test_MAVault_Deployment() public {
        assertEq(vault.owner(), users.alice.account);
        assertEq(vault.keys(), keys);
        assertEq(vault.boundKeyId(), 1); // First key ID.

        KeyConfig memory keyConfig = vault.getKeyConfig();
        assertEq(keyConfig.creator, users.alice.account);
        assertEq(keyConfig.vaultType, VaultType.MULTI);
        assertFalse(keyConfig.isFrozen);
        assertFalse(keyConfig.isBurned);
        assertEq(keyConfig.supply, keySupply);
    }

    function testCannot_Initialize_Implementation_MAVault() public {
        vm.expectRevert("Initializable: contract is already initialized");
        maVault.initialize({ owner_: users.eve.account, keys_: keys, keyAmount_: 0, delegateAssets_: false });
    }

    function testCannot_Initialize_Twice() public {
        hoax(users.eve.account);
        vm.expectRevert("Initializable: contract is already initialized");
        vault.initialize({ owner_: users.eve.account, keys_: keys, keyAmount_: 0, delegateAssets_: false });
    }

    function testCannot_Initialize_MAVault_Owner_ZeroAddressInvalid() public {
        MAVault testVault = new MAVault();
        vm.expectRevert(IMAVault.ZeroAddressInvalid.selector);
        new ERC1967Proxy({
            _logic: address(testVault),
            _data: abi.encodeWithSelector(
                IMAVault.initialize.selector,
                address(0),  // owner
                keys,
                1,
                false
            )
        });
    }

    function testCannot_Initialize_MAVault_Keys_ZeroAddressInvalid() public {
        MAVault testVault = new MAVault();
        vm.expectRevert(IMAVault.ZeroAddressInvalid.selector);
        new ERC1967Proxy({
            _logic: address(testVault),
            _data: abi.encodeWithSelector(
                IMAVault.initialize.selector,
                users.alice.account,
                address(0),  // Keys
                1,
                false
            )
        });
    }

    function test_UnlockAssets_ERC20() public {
        Asset[] memory assets = new Asset[](1);
        assets[0] = getERC20Asset();

        startHoax(users.alice.account);

        mockERC20.transfer(address(vault), assets[0].amount);
        assertEq(mockERC20.balanceOf(address(vault)), assets[0].amount);

        vault.claimOwnership();

        vault.unlockAssets({ assets: assets, receiver: users.alice.account });
        assertEq(mockERC20.balanceOf(address(vault)), 0);
    }

    function test_UnlockAssets_ERC721() public {
        startHoax(users.alice.account);

        mockERC721.transferFrom(users.alice.account, address(vault), 0);
        assertEq(mockERC721.ownerOf(0), address(vault));
        assertEq(mockERC721.balanceOf(address(vault)), 1);

        vault.claimOwnership();

        Asset[] memory assets = new Asset[](1);
        assets[0] = getERC721Asset();

        vault.unlockAssets({ assets: assets, receiver: users.alice.account });
        assertEq(mockERC721.ownerOf(0), users.alice.account);
    }

    function test_UnlockAssets_ERC1155() public {
        Asset[] memory assets = new Asset[](1);
        assets[0] = getERC1155Asset();

        startHoax(users.alice.account);

        mockERC1155.safeTransferFrom(users.alice.account, address(vault), 0, 1, "");
        assertEq(mockERC1155.balanceOf(address(vault), 0), 1);

        vault.claimOwnership();
        vault.unlockAssets({ assets: assets, receiver: users.alice.account });
        assertEq(mockERC1155.balanceOf(users.alice.account, 0), 1);
    }

    function test_UnlockAssets_Many() public {
        Asset[] memory assets = getAssets();

        startHoax(users.alice.account);

        /// Transfer assets in.
        mockERC20.transfer({ to: address(vault), amount: assets[0].amount });
        mockERC721.safeTransferFrom({ from: users.alice.account, to: address(vault), tokenId: assets[1].identifier });
        mockERC1155.safeTransferFrom({
            from: users.alice.account,
            to: address(vault),
            id: assets[2].identifier,
            amount: assets[2].amount,
            data: ""
        });

        vault.claimOwnership();
        vault.unlockAssets({ assets: assets, receiver: users.alice.account });

        assertEq(mockERC20.balanceOf(address(vault)), 0);
        assertEq(mockERC721.balanceOf(address(vault)), 0);
        assertEq(mockERC1155.balanceOf(address(vault), assets[2].identifier), 0);
    }

    function testCannot_UnlockAssets_Unauthorized(address nonOwner) public {
        vm.assume(nonOwner != vault.owner());
        Asset[] memory assets = getAssets();

        hoax(nonOwner);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        vault.unlockAssets({ assets: assets, receiver: nonOwner });
    }

    function testCannot_UnlockAssets_ZeroAssetAmount() public {
        Asset[] memory assets = new Asset[](0);

        hoax(users.alice.account);
        vm.expectRevert(IMAVault.ZeroAssetAmount.selector);
        vault.unlockAssets({ assets: assets, receiver: users.alice.account });
    }

    function testCannot_UnlockAssets_ZeroAddressInvalid() public {
        Asset[] memory assets = new Asset[](1);

        hoax(users.alice.account);
        vm.expectRevert(IMAVault.ZeroAddressInvalid.selector);
        vault.unlockAssets({ assets: assets, receiver: address(0) });
    }

    function testCannot_UnlockAssets_KeysBindedToVault() public {
        Asset[] memory assets = getAssets();

        hoax(users.alice.account);
        vm.expectRevert(IMAVault.KeysBindedToVault.selector);
        vault.unlockAssets({ assets: assets, receiver: users.alice.account });
    }

    function testCannot_UnlockAssets_NoneAssetType() public {
        Asset[] memory assets = getAssets();
        assets[0].class = AssetClass.NONE;

        startHoax(users.alice.account);
        vault.claimOwnership();

        vm.expectRevert(IMAVault.NoneAssetType.selector);
        vault.unlockAssets({ assets: assets, receiver: users.alice.account });
    }

    function test_UnlockNativeToken_Fuzzed(uint256 amount) public {
        amount = bound(amount, 1 wei, 100 ether);
        deal(address(vault), amount);

        assertEq(address(vault).balance, amount);

        startHoax(users.alice.account, 0 ether);
        vault.claimOwnership();

        vm.expectEmit({ checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true });
        emit NativeTokenUnlocked({ receiver: users.alice.account, amount: amount });
        vault.unlockNativeToken(users.alice.account);

        assertEq(users.alice.account.balance, amount);
        assertEq(address(vault).balance, 0 ether);
    }

    function testCannot_UnlockNativeToken_Unauthorized(address nonOwner) public {
        vm.assume(nonOwner != vault.owner());

        hoax(nonOwner);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        vault.unlockNativeToken(nonOwner);
    }

    function testCannot_UnlockNativeToken_ZeroAddressInvalid() public {
        uint256 amount = 1 ether;
        deal(address(vault), amount);
        assertEq(address(vault).balance, amount);

        startHoax(users.alice.account, 0 ether);
        vault.claimOwnership();

        vm.expectRevert(IMAVault.ZeroAddressInvalid.selector);
        vault.unlockNativeToken({ receiver: address(0) });
    }

    function testCannot_UnlockNativeToken_KeysBindedToVault() public {
        hoax(users.alice.account);
        vm.expectRevert(IMAVault.KeysBindedToVault.selector);
        vault.unlockNativeToken(users.alice.account);
    }

    function testCannot_UnlockNativeToken_NativeTokenUnlockFailed() public {
        uint256 amount = 1 ether;
        deal({ to: address(vault), give: amount });
        assertEq(address(vault).balance, amount);

        vm.mockCallRevert({ callee: users.alice.account, data: "", revertData: "" });

        startHoax(users.alice.account);
        vault.claimOwnership();

        vm.expectRevert(IMAVault.NativeTokenUnlockFailed.selector);
        vault.unlockNativeToken(users.alice.account);
    }

    function test_ClaimOwnership() public {
        uint256 keyId = vault.boundKeyId();

        assertEq(vault.owner(), users.alice.account);
        assertEq(keys.balanceOf(users.alice.account, keyId), keySupply);
        assertEq(keys.balanceOf(users.bob.account, keyId), 0);

        /// Transfer keys to Bob.
        hoax(users.alice.account);
        keys.safeTransferFrom(users.alice.account, users.bob.account, keyId, keySupply, "");
        assertEq(keys.balanceOf(users.alice.account, keyId), 0);
        assertEq(keys.balanceOf(users.bob.account, keyId), keySupply);

        hoax(users.bob.account);
        vault.claimOwnership();
        assertEq(keys.balanceOf(users.alice.account, keyId), 0);
        assertEq(keys.balanceOf(users.bob.account, keyId), 0);
        assertEq(vault.boundKeyId(), 0);
        assertEq(vault.owner(), users.bob.account);

        KeyConfig memory keyConfig = keys.getKeyConfig(keyId);
        assertEq(keyConfig.creator, users.alice.account);
        assertEq(keyConfig.vaultType, VaultType.MULTI);
        assertFalse(keyConfig.isFrozen);
        assertTrue(keyConfig.isBurned);
        assertEq(keyConfig.supply, keySupply);
    }

    function testCannot_ClaimOwnership_NoKeysBindedToVault() public {
        startHoax(users.alice.account);
        vault.claimOwnership();
        vm.expectRevert(IMAVault.NoKeysBindedToVault.selector);
        vault.claimOwnership();
    }

    function testCannot_ClaimOwnership_BurnExceedsBalance() public {
        hoax(users.bob.account);
        vm.expectRevert("ERC1155: burn amount exceeds balance");
        vault.claimOwnership();
    }

    // TODO: Finish tests for `modifyAssetDelegation`.

    function test_ModifyAssetDelegation() public {
        // Confirm that there are no outgoing delegations as Alice created the vault with `delegateAssets_` as false.
        IDelegateRegistry.Delegation[] memory delegations = delegateRegistry.getOutgoingDelegations(address(vault));
        assertEq(delegations.length, 0);

        /// Approve Alice's delegation rights for all.
        bytes[] memory delegationPayloads = new bytes[](1);
        delegationPayloads[0] = abi.encodeWithSelector(
            IDelegateRegistry.delegateAll.selector,
            users.alice.account,  // `to`
            bytes32(""),        // `rights`
            true                // `enable`
        );

        hoax(users.alice.account);
        vm.expectEmit({ checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true });
        emit DelegationPerformed({ delegationHash: 0x4fd98b4ab70d00e9fd2b80daf2480ad1b0e9e320468f35effbeb4489cb32e001 });
        vault.modifyAssetDelegation(delegationPayloads);

        /// Check outgoing delegations for `vault` and ensure Bob is the only delegate with full rights.
        delegations = delegateRegistry.getOutgoingDelegations(address(vault));
        assertEq(delegations.length, 1);
        assertEq(delegations[0].type_, IDelegateRegistry.DelegationType.ALL);
        assertEq(delegations[0].to, users.alice.account);
        assertEq(delegations[0].from, address(vault));
        assertEq(delegations[0].contract_, address(0));
        assertEq(delegations[0].tokenId, 0);
        assertEq(delegations[0].amount, 0);
    }

    function testCannot_ModifyAssetDelegation_Unauthorized_Fuzzed(address notOwner) public {
        vm.assume(notOwner != vault.owner());

        hoax(notOwner);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        vault.modifyAssetDelegation({ delegationPayloads: new bytes[](1) });
    }

    function testCannot_ModifyAssetDelegation_ZeroLengthArray() public {
        hoax(users.alice.account);
        vm.expectRevert(IMAVault.ZeroLengthArray.selector);
        vault.modifyAssetDelegation({ delegationPayloads: new bytes[](0) });
    }

    function test_OnERC1155BatchReceived() public {
        uint256 length = 5;
        uint256[] memory tokenIds = new uint256[](length);
        uint256[] memory amounts = new uint256[](length);

        startHoax(users.alice.account);
        for (uint256 tokenId = 1; tokenId <= length; tokenId++) {
            mockERC1155.mint({ receiver: users.alice.account, id: tokenId, amount: 1 });
            tokenIds[tokenId - 1] = tokenId;
            amounts[tokenId - 1] = 1;
        }

        mockERC1155.safeBatchTransferFrom(users.alice.account, address(vault), tokenIds, amounts, "");
    }
}
