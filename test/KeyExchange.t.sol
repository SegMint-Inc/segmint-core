// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./Base.sol";

contract KeyExchangeTest is Base {
    // function setUp() public override {
    //     vm.createSelectFork("https://eth-mainnet.g.alchemy.com/v2/MHZxwiVRNfWx7fRai3zK9iFhoFpYA-02", 18020000);

    //     super.setUp();

    //     IKYCRegistry.AccessType accessType = IKYCRegistry.AccessType.RESTRICTED;
    //     bytes memory signature =
    //         getAccessSignature({ account: users.alice, deadline: block.timestamp, accessType: accessType });

    //     // Grant restricted access to Alice.
    //     hoax(users.alice, users.alice);
    //     kycRegistry.initAccessType({ signature: signature, deadline: block.timestamp, newAccessType: accessType });

    //     signature = getAccessSignature({ account: users.bob, deadline: block.timestamp, accessType: accessType });

    //     // Grant restricted access to Bob.
    //     hoax(users.bob, users.bob);
    //     kycRegistry.initAccessType({ signature: signature, deadline: block.timestamp, newAccessType: accessType });

    //     signature =
    //         getVaultCreateSignature({ account: users.alice, accessType: accessType, nonce: 0, discriminator: "SAV" });

    //     startHoax(users.alice, users.alice);
    //     demoERC721.setApprovalForAll(address(serviceFactoryProxied), true);
    //     serviceFactoryProxied.createSingleAssetVault({
    //         asset: Asset({ class: AssetClass.ERC721, token: address(demoERC721), identifier: 5, amount: 1 }),
    //         keyAmount: 5,
    //         signature: signature
    //     });

    //     keys.setApprovalForAll(address(keyExchange), true);
    //     keyExchange.setKeyTerms({
    //         finalTerms: IKeyExchange.KeyTerms({
    //             market: IKeyExchange.MarketType.BUY_OUT,
    //             buyBack: 0.2 ether,
    //             reserve: 0.3 ether
    //         }),
    //         keyId: 1
    //     });
    //     vm.stopPrank();
    // }

    // function test_ExecuteOrder() public {
    //     address saVault = serviceFactoryProxied.getSingleAssetVaults(users.alice)[0];
    //     (uint256 keyId,) = SAVault(saVault).boundKeyId();

    //     IKeyExchange.Order memory userOrder = IKeyExchange.Order({
    //         price: 0.1 ether,
    //         maker: users.alice,
    //         taker: address(0),
    //         keyId: keyId,
    //         amount: 3,
    //         nonce: 0,
    //         startTime: block.timestamp,
    //         endTime: block.timestamp + 5 days
    //     });

    //     bytes32 orderHash = keyExchange.hashOrder(userOrder);
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, orderHash);
    //     bytes memory signature = abi.encodePacked(r, s, v);

    //     IKeyExchange.OrderParams memory orderParams =
    //         IKeyExchange.OrderParams({ order: userOrder, signature: signature });

    //     uint256 aliceInitialBalance = users.alice.balance;
    //     uint256 bobInitialBalance = users.bob.balance;
    //     uint256 fee = userOrder.price * 500 / 10_000; // 5% fee.

    //     hoax(users.bob, users.bob);
    //     keyExchange.executeOrder{ value: 0.1 ether }(orderParams);

    //     assertEq(users.alice.balance, aliceInitialBalance + userOrder.price - fee);
    //     assertEq(users.bob.balance, bobInitialBalance - userOrder.price);
    //     assertEq(keyExchange.feeReceiver().balance, fee);
    //     assertEq(keys.balanceOf(users.bob, userOrder.keyId), userOrder.amount);

    //     IKeyExchange.OrderStatus orderStatus = keyExchange.orderStatus(orderHash);
    //     assertEq(uint256(orderStatus), uint256(IKeyExchange.OrderStatus.FILLED));
    // }

    // function test_ExecuteBid() public {
    //     address saVault = serviceFactoryProxied.getSingleAssetVaults(users.alice)[0];
    //     (uint256 keyId,) = SAVault(saVault).keyBinds();

    //     IKeyExchange.Bid memory userBid = IKeyExchange.Bid({
    //         maker: users.bob,
    //         price: 0.1 ether,
    //         keyId: keyId,
    //         amount: 1,
    //         startTime: block.timestamp,
    //         endTime: block.timestamp + 1 hours
    //     });

    //     bytes32 bidHash = keyExchange.hashBid(userBid);
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPrivateKey, bidHash);
    //     bytes memory signature = abi.encodePacked(r, s, v);

    //     deal({ token: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, to: users.bob, give: 0.1 ether });

    //     hoax(users.bob, users.bob);
    //     IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2).approve(address(keyExchange), 0.1 ether);

    //     IKeyExchange.BidParams memory bidParams = IKeyExchange.BidParams({ bid: userBid, signature: signature });

    //     hoax(users.alice, users.alice);
    //     keyExchange.executeBid(bidParams);
    // }
}
