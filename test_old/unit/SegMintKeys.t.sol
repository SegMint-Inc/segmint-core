// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../Base.t.sol";

contract SegMintKYCRegistryTest is Base {
    SegMintVaultSingle internal aliceVault;

    function setUp() public override {
        super.setUp();

        /// KYC users.
        kycUsers();

        /// Since `factoryProxy` is a proxy, interface the proxy as the implementation contract.
        factory = SegMintFactory(address(factoryProxy));

        /// Grant `factory` the ability to approve vaults for `keys`.
        keys.grantRoles(address(factory), VAULT_MANAGER_ROLE);

        /// Define the asset to be locked.
        Vault.Asset memory asset = getSingleLockAsset();

        /// Approve vault manager for asset movement and create a new single vault.
        startHoax(users.alice, users.alice);
        erc721.setApprovalForAll(address(factory), true);
        factory.createVaultWithKeys(asset, 5);
        vm.stopPrank();

        /// Define `aliceVault`.
        address[] memory userVaults = factory.getSingleVaults({ account: users.alice });
        aliceVault = SegMintVaultSingle(userVaults[0]);

        vm.label({ account: address(aliceVault), newLabel: "Alice's Single Vault" });
    }

    function testKeyLending() public {
        startHoax(users.alice, users.alice);
        
        uint256 keyId = 1;
        uint256 totalKeys = 5;
        uint256 lendAmount = 2;
        
        // Approve {SegMintKeys} to move assets on behalf of Alice.
        keys.setApprovalForAll(address(keys), true);
        assertEq(keys.balanceOf({ account: users.alice, id: keyId}), totalKeys);
        
        // Lend key out to Bob.
        assertEq(keys.balanceOf({ account: users.bob, id: keyId}), 0);
        keys.lendKeys({ lendee: users.bob, keyId: keyId, lendAmount: lendAmount, lendDuration: 3 days });
        assertEq(keys.balanceOf({ account: users.bob, id: keyId}), lendAmount);
        assertEq(keys.balanceOf({ account: users.alice, id: keyId}), 3);

        // Assert that Alice can no longer lend the same key ID to Bob.
        vm.expectRevert(SegMintKeys.HasActiveLend.selector);
        keys.lendKeys({ lendee: users.bob, keyId: keyId, lendAmount: lendAmount, lendDuration: 3 days });
        vm.stopPrank();

        // Ensure that Bob can't move the asset while the key is lent.
        hoax(users.bob, users.bob);
        vm.expectRevert();
        keys.safeTransferFrom({
            from: users.bob,
            to: users.bob,
            id: keyId,
            value: 1,
            data: ""
        });

        // Warp to the future.
        uint256 lendExpiryTime = block.timestamp + 3 days;
        vm.warp(lendExpiryTime);

        // Reclaim the key.
        hoax(users.alice, users.alice);
        keys.reclaimKeys({ lendee: users.bob, keyId: keyId });
        assertEq(keys.balanceOf({ account: users.alice, id: keyId}), totalKeys);
        assertEq(keys.balanceOf({ account: users.bob, id: keyId}), 0);
    }

    /* Helper Functions */

    function getSingleLockAsset() internal view returns (Vault.Asset memory) {
        return Vault.Asset({ assetType: AssetType.ERC721, token: address(erc721), identifier: ALICE_NFT_ID, amount: 1 });
    }

}