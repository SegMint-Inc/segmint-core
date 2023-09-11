// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "./BaseTest.sol";

/// TODO: Native transfer failure tests.

contract KeyExchangeTest is BaseTest {
    using stdStorage for StdStorage;

    /// Key term constants.
    uint256 public constant defaultBuyBackPrice = 0.75 ether;
    uint256 public constant defaultReservePrice = 1 ether;

    /// Generic order constants.
    uint256 public constant defaultOrderPrice = 0.5 ether;
    uint256 public constant defaultOrderAmount = 5;

    /// Generic bid constants.
    uint256 public constant defaultBidAmount = 3;
    uint256 public constant defaultBidPrice = 0.25 ether;

    /// Values used for order execution.
    uint256 private keyId;
    uint256 private keySupply;

    modifier setKeyTerms(IKeyExchange.MarketType marketType) {
        hoax(users.alice.account);
        if (marketType == IKeyExchange.MarketType.FREE) {
            keyExchange.setKeyTerms(keyId, IKeyExchange.KeyTerms(marketType, 0, 0));
        } else {
            keyExchange.setKeyTerms(keyId, IKeyExchange.KeyTerms(marketType, defaultBuyBackPrice, defaultReservePrice));
        }

        _;
    }

    function setUp() public override {
        super.setUp();
        kycUsers();

        /// Spoof storage so that Alice is a registered vault.
        string memory funcSignature = "isRegistered(address)";
        stdstore.target(address(keys)).sig(funcSignature).with_key(users.alice.account).checked_write(true);
        assertTrue(keys.isRegistered(users.alice.account));

        /// Define the key supply as the maximum amount of keys.
        keySupply = keys.MAX_KEYS();

        /// Create the keys to be used for trading.
        hoax(users.alice.account);
        keyId = keys.createKeys(keySupply, users.alice.account, VaultType.SINGLE);
    }

    function test_ExecuteOrders_Single() public setKeyTerms(IKeyExchange.MarketType.FREE) {
        IKeyExchange.Order memory order = getGenericOrder(users.alice.account);
        bytes32 orderHash = keyExchange.hashOrder(order);

        IKeyExchange.OrderParams[] memory orders = new IKeyExchange.OrderParams[](1);
        orders[0] = signOrder(order, users.alice.privateKey);

        assertEq(keyExchange.orderStatus(orderHash), IKeyExchange.Status.OPEN);
        assertEq(keys.balanceOf(users.alice.account, order.keyId), keySupply);
        assertEq(keys.balanceOf(users.bob.account, order.keyId), 0);

        uint256 initialMakerBalance = users.alice.account.balance;
        uint256 initialFeeBalance = keyExchange.feeReceiver().balance;

        hoax(users.bob.account, order.price);
        vm.expectEmit({ checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true });
        emit OrderFilled({ orderHash: orderHash });
        keyExchange.executeOrders{ value: order.price }(orders);

        assertEq(keyExchange.orderStatus(orderHash), IKeyExchange.Status.FILLED);
        assertEq(keys.balanceOf(users.alice.account, order.keyId), keySupply - order.amount);
        assertEq(keys.balanceOf(users.bob.account, order.keyId), order.amount);

        uint256 expectedFee = order.price * keyExchange.protocolFee() / 10_000;
        uint256 expectedEarnings = order.price - expectedFee;

        assertEq(users.alice.account.balance, initialMakerBalance + expectedEarnings);
        assertEq(users.bob.account.balance, 0);
        assertEq(keyExchange.feeReceiver().balance, initialFeeBalance + expectedFee);
    }

    function test_ExecuteOrders_Single_RefundsExcess(uint256 excess) public setKeyTerms(IKeyExchange.MarketType.FREE) {
        excess = bound(excess, 1 wei, 10 ether);

        IKeyExchange.Order memory order = getGenericOrder(users.alice.account);
        bytes32 orderHash = keyExchange.hashOrder(order);

        IKeyExchange.OrderParams[] memory orders = new IKeyExchange.OrderParams[](1);
        orders[0] = signOrder(order, users.alice.privateKey);

        assertEq(keyExchange.orderStatus(orderHash), IKeyExchange.Status.OPEN);
        assertEq(keys.balanceOf(users.alice.account, order.keyId), keySupply);
        assertEq(keys.balanceOf(users.bob.account, order.keyId), 0);

        uint256 initialMakerBalance = users.alice.account.balance;
        uint256 initialFeeBalance = keyExchange.feeReceiver().balance;

        hoax(users.bob.account, order.price + excess);
        vm.expectEmit({ checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true });
        emit OrderFilled({ orderHash: orderHash });
        keyExchange.executeOrders{ value: order.price }(orders);

        assertEq(keyExchange.orderStatus(orderHash), IKeyExchange.Status.FILLED);
        assertEq(keys.balanceOf(users.alice.account, order.keyId), keySupply - order.amount);
        assertEq(keys.balanceOf(users.bob.account, order.keyId), order.amount);

        uint256 expectedFee = order.price * keyExchange.protocolFee() / 10_000;
        uint256 expectedEarnings = order.price - expectedFee;

        assertEq(users.alice.account.balance, initialMakerBalance + expectedEarnings);
        assertEq(users.bob.account.balance, excess);
        assertEq(keyExchange.feeReceiver().balance, initialFeeBalance + expectedFee);
    }

    function testCannot_ExecuteOrders_ZeroLengthArray() public {
        IKeyExchange.OrderParams[] memory orders = new IKeyExchange.OrderParams[](0);

        hoax(users.bob.account);
        vm.expectRevert(IKeyExchange.ZeroLengthArray.selector);
        keyExchange.executeOrders(orders);
    }

    function testCannot_ExecuteOrders_KeyTermsUndefined() public {
        IKeyExchange.Order memory order = getGenericOrder(users.alice.account);
        IKeyExchange.OrderParams[] memory orders = new IKeyExchange.OrderParams[](1);
        orders[0] = signOrder(order, users.alice.privateKey);

        hoax(users.bob.account);
        vm.expectRevert(IKeyExchange.KeyTermsUndefined.selector);
        keyExchange.executeOrders{ value: order.price }(orders);
    }

    function testCannot_ExecuteOrders_MultiAssetKeysRestricted() public {
        startHoax(users.alice.account); // Create multi-asset vault keys and set key terms.
        uint256 id = keys.createKeys(keySupply, users.alice.account, VaultType.MULTI);
        keyExchange.setKeyTerms(id, IKeyExchange.KeyTerms(IKeyExchange.MarketType.FREE, 0, 0));
        vm.stopPrank();

        IKeyExchange.Order memory order = getGenericOrder(users.alice.account);
        order.keyId = id; // Modify the order key ID to be a multi-asset ID.

        IKeyExchange.OrderParams[] memory orders = new IKeyExchange.OrderParams[](1);
        orders[0] = signOrder(order, users.alice.privateKey);

        hoax(users.bob.account);
        vm.expectRevert(IKeyExchange.MultiAssetKeysRestricted.selector);
        keyExchange.executeOrders{ value: order.price }(orders);
    }

    function testCannot_ExecuteOrders_InvalidOrderStatus() public setKeyTerms(IKeyExchange.MarketType.FREE) {
        IKeyExchange.Order memory order = getGenericOrder(users.alice.account);
        IKeyExchange.OrderParams[] memory orders = new IKeyExchange.OrderParams[](1);
        orders[0] = signOrder(order, users.alice.privateKey);

        hoax(users.bob.account);
        keyExchange.executeOrders{ value: order.price }(orders);
        vm.expectRevert(IKeyExchange.InvalidOrderStatus.selector);
        keyExchange.executeOrders{ value: order.price }(orders);
    }

    function testCannot_ExecuteOrders_SignerNotMaker() public setKeyTerms(IKeyExchange.MarketType.FREE) {
        IKeyExchange.Order memory order = getGenericOrder(users.alice.account);
        IKeyExchange.OrderParams[] memory orders = new IKeyExchange.OrderParams[](1);
        orders[0] = signOrder(order, users.bob.privateKey);

        hoax(users.bob.account);
        vm.expectRevert(IKeyExchange.SignerNotMaker.selector);
        keyExchange.executeOrders{ value: order.price }(orders);
    }

    function testCannot_ExecuteOrders_CallerNotTaker() public setKeyTerms(IKeyExchange.MarketType.FREE) {
        IKeyExchange.Order memory order = getGenericOrder(users.alice.account);
        order.taker = users.eve.account; // Modify order taker.

        IKeyExchange.OrderParams[] memory orders = new IKeyExchange.OrderParams[](1);
        orders[0] = signOrder(order, users.alice.privateKey);

        hoax(users.bob.account);
        vm.expectRevert(IKeyExchange.CallerNotTaker.selector);
        keyExchange.executeOrders{ value: order.price }(orders);
    }

    function testCannot_ExecuteOrders_InactiveOrderOrBid() public setKeyTerms(IKeyExchange.MarketType.FREE) {
        IKeyExchange.Order memory order = getGenericOrder(users.alice.account);
        IKeyExchange.OrderParams[] memory orders = new IKeyExchange.OrderParams[](1);
        orders[0] = signOrder(order, users.alice.privateKey);

        vm.warp(order.startTime - 1 seconds);

        hoax(users.bob.account);
        vm.expectRevert(IKeyExchange.InactiveOrderOrBid.selector);
        keyExchange.executeOrders{ value: order.price }(orders);
    }

    function testCannot_ExecuteOrders_ExpiredOrderOrBid() public setKeyTerms(IKeyExchange.MarketType.FREE) {
        IKeyExchange.Order memory order = getGenericOrder(users.alice.account);
        IKeyExchange.OrderParams[] memory orders = new IKeyExchange.OrderParams[](1);
        orders[0] = signOrder(order, users.alice.privateKey);

        vm.warp(order.endTime + 1 seconds);

        hoax(users.bob.account);
        vm.expectRevert(IKeyExchange.ExpiredOrderOrBid.selector);
        keyExchange.executeOrders{ value: order.price }(orders);
    }

    function testCannot_ExecuteOrders_NativeTransferFailed_OnWethSend()
        public
        setKeyTerms(IKeyExchange.MarketType.FREE)
    {
        IKeyExchange.Order memory order = getGenericOrder(users.alice.account);
        IKeyExchange.OrderParams[] memory orders = new IKeyExchange.OrderParams[](1);
        orders[0] = signOrder(order, users.alice.privateKey);

        uint256 expectedFee = order.price * keyExchange.protocolFee() / 10_000;
        uint256 expectedEarnings = order.price - expectedFee;

        bytes memory callData = abi.encodeWithSelector(mockWETH.transfer.selector, order.maker, expectedEarnings);

        /// Revert on the native token transfer.
        vm.mockCallRevert({ callee: order.maker, data: "", revertData: abi.encode(false) });

        /// Return false on the wrapper native token transfer.
        vm.mockCall({ callee: address(mockWETH), data: callData, returnData: abi.encode(false) });

        hoax(users.bob.account);
        vm.expectRevert(IKeyExchange.NativeTransferFailed.selector);
        keyExchange.executeOrders{ value: order.price }(orders);
    }

    function testCannot_ExecuteOrders_InvalidNativeTokenAmount() public setKeyTerms(IKeyExchange.MarketType.FREE) {
        IKeyExchange.Order memory order = getGenericOrder(users.alice.account);
        IKeyExchange.OrderParams[] memory orders = new IKeyExchange.OrderParams[](1);
        orders[0] = signOrder(order, users.alice.privateKey);

        hoax(users.bob.account);
        vm.expectRevert(IKeyExchange.InvalidNativeTokenAmount.selector);
        keyExchange.executeOrders{ value: order.price - 1 wei }(orders);
    }

    function testCannot_ExecuteOrders_NativeTransferFailed_Fees() public setKeyTerms(IKeyExchange.MarketType.FREE) {
        IKeyExchange.Order memory order = getGenericOrder(users.alice.account);
        IKeyExchange.OrderParams[] memory orders = new IKeyExchange.OrderParams[](1);
        orders[0] = signOrder(order, users.alice.privateKey);

        vm.mockCallRevert({ callee: keyExchange.feeReceiver(), data: "", revertData: "" });

        hoax(users.bob.account);
        vm.expectRevert(IKeyExchange.NativeTransferFailed.selector);
        keyExchange.executeOrders{ value: order.price }(orders);
    }

    function testCannot_ExecuteOrders_NativeTransferFailed_Refund() public setKeyTerms(IKeyExchange.MarketType.FREE) {
        IKeyExchange.Order memory order = getGenericOrder(users.alice.account);
        IKeyExchange.OrderParams[] memory orders = new IKeyExchange.OrderParams[](1);
        orders[0] = signOrder(order, users.alice.privateKey);

        vm.mockCallRevert({ callee: users.bob.account, data: "", revertData: "" });

        hoax(users.bob.account);
        vm.expectRevert(IKeyExchange.NativeTransferFailed.selector);
        keyExchange.executeOrders{ value: order.price + 1 wei }(orders);
    }

    function testCannot_ExecuteOrders_NativeTransferFailed_OnMsgValueGtZero(uint256 excess)
        public
        setKeyTerms(IKeyExchange.MarketType.FREE)
    {
        excess = bound(excess, 1 wei, 10 ether);

        IKeyExchange.Order memory order = getGenericOrder(users.alice.account);
        IKeyExchange.OrderParams[] memory orders = new IKeyExchange.OrderParams[](1);
        orders[0] = signOrder(order, users.alice.privateKey);

        /// Revert the refund call to the order taker.
        vm.mockCallRevert({ callee: users.bob.account, msgValue: excess, data: "", revertData: abi.encode(false) });

        hoax(users.bob.account);
        vm.expectRevert(IKeyExchange.NativeTransferFailed.selector);
        keyExchange.executeOrders{ value: order.price + excess }(orders);
    }

    function test_ExecuteBids() public setKeyTerms(IKeyExchange.MarketType.FREE) {
        IKeyExchange.Bid memory bid = getGenericBid(users.bob.account);
        bytes32 bidHash = keyExchange.hashBid(bid);

        IKeyExchange.BidParams[] memory bids = new IKeyExchange.BidParams[](1);
        bids[0] = signBid(bid, users.bob.privateKey);

        assertEq(keyExchange.bidStatus(bidHash), IKeyExchange.Status.OPEN);
        assertEq(keys.balanceOf(users.alice.account, bid.keyId), keySupply);
        assertEq(keys.balanceOf(users.bob.account, bid.keyId), 0);

        startHoax(users.bob.account);
        mockWETH.deposit{ value: bid.price }();
        mockWETH.approve(address(keyExchange), type(uint256).max);
        vm.stopPrank();

        hoax(users.alice.account);
        vm.expectEmit({ checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true });
        emit BidFilled({ bidHash: bidHash });
        keyExchange.executeBids(bids);

        assertEq(keyExchange.bidStatus(bidHash), IKeyExchange.Status.FILLED);
        assertEq(keys.balanceOf(users.alice.account, bid.keyId), keySupply - bid.amount);
        assertEq(keys.balanceOf(users.bob.account, bid.keyId), bid.amount);

        uint256 expectedFee = bid.price * keyExchange.protocolFee() / 10_000;
        uint256 expectedEarnings = bid.price - expectedFee;

        assertEq(mockWETH.balanceOf(users.alice.account), expectedEarnings);
        assertEq(mockWETH.balanceOf(users.bob.account), 0);
        assertEq(mockWETH.balanceOf(keyExchange.feeReceiver()), expectedFee);
    }

    function testCannot_ExecuteBids_ZeroLengthArray() public {
        IKeyExchange.BidParams[] memory bids = new IKeyExchange.BidParams[](0);

        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.ZeroLengthArray.selector);
        keyExchange.executeBids(bids);
    }

    function testCannot_ExecuteBids_KeyTermsUndefined() public {
        IKeyExchange.Bid memory bid = getGenericBid(users.bob.account);
        IKeyExchange.BidParams[] memory bids = new IKeyExchange.BidParams[](1);
        bids[0] = signBid(bid, users.bob.privateKey);

        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.KeyTermsUndefined.selector);
        keyExchange.executeBids(bids);
    }

    function testCannot_ExecuteBids_MultiAssetKeysRestricted() public {
        startHoax(users.alice.account); // Create multi-asset vault keys and set key terms.
        uint256 id = keys.createKeys(keySupply, users.alice.account, VaultType.MULTI);
        keyExchange.setKeyTerms(id, IKeyExchange.KeyTerms(IKeyExchange.MarketType.FREE, 0, 0));
        vm.stopPrank();

        IKeyExchange.Bid memory bid = getGenericBid(users.alice.account);
        bid.keyId = id; // Modify the bid key ID to be a multi-asset ID.

        IKeyExchange.BidParams[] memory bids = new IKeyExchange.BidParams[](1);
        bids[0] = signBid(bid, users.bob.privateKey);

        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.MultiAssetKeysRestricted.selector);
        keyExchange.executeBids(bids);
    }

    function testCannot_ExecuteBids_InvalidBidStatus() public setKeyTerms(IKeyExchange.MarketType.FREE) {
        IKeyExchange.Bid memory bid = getGenericBid(users.bob.account);
        IKeyExchange.BidParams[] memory bids = new IKeyExchange.BidParams[](1);
        bids[0] = signBid(bid, users.bob.privateKey);

        startHoax(users.bob.account);
        mockWETH.deposit{ value: bid.price }();
        mockWETH.approve(address(keyExchange), type(uint256).max);
        vm.stopPrank();

        startHoax(users.alice.account);
        keyExchange.executeBids(bids);
        vm.expectRevert(IKeyExchange.InvalidBidStatus.selector);
        keyExchange.executeBids(bids);
    }

    function testCannot_ExecuteBids_SignerNotMaker() public setKeyTerms(IKeyExchange.MarketType.FREE) {
        IKeyExchange.Bid memory bid = getGenericBid(users.bob.account);
        IKeyExchange.BidParams[] memory bids = new IKeyExchange.BidParams[](1);
        bids[0] = signBid(bid, users.eve.privateKey);

        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.SignerNotMaker.selector);
        keyExchange.executeBids(bids);
    }

    function testCannot_ExecuteBids_InactiveOrderOrBid() public setKeyTerms(IKeyExchange.MarketType.FREE) {
        IKeyExchange.Bid memory bid = getGenericBid(users.bob.account);
        IKeyExchange.BidParams[] memory bids = new IKeyExchange.BidParams[](1);
        bids[0] = signBid(bid, users.bob.privateKey);

        vm.warp(bid.startTime - 1 seconds);

        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.InactiveOrderOrBid.selector);
        keyExchange.executeBids(bids);
    }

    function testCannot_ExecuteBids_ExpiredOrderOrBid() public setKeyTerms(IKeyExchange.MarketType.FREE) {
        IKeyExchange.Bid memory bid = getGenericBid(users.bob.account);
        IKeyExchange.BidParams[] memory bids = new IKeyExchange.BidParams[](1);
        bids[0] = signBid(bid, users.bob.privateKey);

        vm.warp(bid.endTime + 1 seconds);

        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.ExpiredOrderOrBid.selector);
        keyExchange.executeBids(bids);
    }

    function testCannot_ExecuteBids_NativeTokenTransferFailed_Fees() public setKeyTerms(IKeyExchange.MarketType.FREE) {
        IKeyExchange.Bid memory bid = getGenericBid(users.bob.account);
        IKeyExchange.BidParams[] memory bids = new IKeyExchange.BidParams[](1);
        bids[0] = signBid(bid, users.bob.privateKey);

        vm.mockCall({ callee: address(mockWETH), data: "", returnData: abi.encode(false) });

        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.NativeTransferFailed.selector);
        keyExchange.executeBids(bids);
    }

    function testCannot_ExecuteBids_NativeTokenTransferFailed_Taker()
        public
        setKeyTerms(IKeyExchange.MarketType.FREE)
    {
        IKeyExchange.Bid memory bid = getGenericBid(users.bob.account);
        IKeyExchange.BidParams[] memory bids = new IKeyExchange.BidParams[](1);
        bids[0] = signBid(bid, users.bob.privateKey);

        /// Give Bob the appropriate amount of WETH.
        deal({ token: address(mockWETH), to: users.bob.account, give: bid.price });

        /// Approve Key Exchange to move WETH on Bobs behalf.
        hoax(users.bob.account);
        mockWETH.approve(address(keyExchange), type(uint256).max);

        uint256 calculatedFee = bid.price * keyExchange.protocolFee() / 10_000;
        uint256 takerEarnings = bid.price - calculatedFee;

        /// Ensure the WETH transfer of earnings to Alice fails and returns false.
        bytes4 selector = mockWETH.transferFrom.selector;
        bytes memory data = abi.encodeWithSelector(selector, bid.maker, users.alice.account, takerEarnings);
        vm.mockCall({ callee: address(mockWETH), data: data, returnData: abi.encode(false) });

        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.NativeTransferFailed.selector);
        keyExchange.executeBids(bids);
    }

    function test_CancelOrders() public setKeyTerms(IKeyExchange.MarketType.FREE) {
        IKeyExchange.Order[] memory orders = new IKeyExchange.Order[](1);
        orders[0] = getGenericOrder(users.alice.account);

        bytes32 orderHash = keyExchange.hashOrder(orders[0]);
        assertEq(keyExchange.orderStatus(orderHash), IKeyExchange.Status.OPEN);

        hoax(users.alice.account);
        vm.expectEmit({ checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true });
        emit OrderCancelled({ orderHash: orderHash });
        keyExchange.cancelOrders(orders);

        assertEq(keyExchange.orderStatus(orderHash), IKeyExchange.Status.CANCELLED);
    }

    function testCannot_CancelOrders_ZeroLengthArray() public {
        IKeyExchange.Order[] memory orders = new IKeyExchange.Order[](0);

        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.ZeroLengthArray.selector);
        keyExchange.cancelOrders(orders);
    }

    function testCannot_CancelOrders_CallerNotMaker() public {
        IKeyExchange.Order[] memory orders = new IKeyExchange.Order[](1);
        orders[0] = getGenericOrder(users.alice.account);

        hoax(users.bob.account);
        vm.expectRevert(IKeyExchange.CallerNotMaker.selector);
        keyExchange.cancelOrders(orders);
    }

    function testCannot_CancelOrders_InvalidOrderStatus() public {
        IKeyExchange.Order[] memory orders = new IKeyExchange.Order[](1);
        orders[0] = getGenericOrder(users.alice.account);

        bytes32 orderHash = keyExchange.hashOrder(orders[0]);
        assertEq(keyExchange.orderStatus(orderHash), IKeyExchange.Status.OPEN);

        startHoax(users.alice.account);
        keyExchange.cancelOrders(orders);
        vm.expectRevert(IKeyExchange.InvalidOrderStatus.selector);
        keyExchange.cancelOrders(orders);
    }

    function test_CancelBids() public {
        IKeyExchange.Bid[] memory bids = new IKeyExchange.Bid[](1);
        bids[0] = getGenericBid(users.bob.account);

        bytes32 bidHash = keyExchange.hashBid(bids[0]);
        assertEq(keyExchange.bidStatus(bidHash), IKeyExchange.Status.OPEN);

        hoax(users.bob.account);
        vm.expectEmit({ checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true });
        emit BidCancelled({ bidHash: bidHash });
        keyExchange.cancelBids(bids);

        assertEq(keyExchange.bidStatus(bidHash), IKeyExchange.Status.CANCELLED);
    }

    function testCannot_CancelBids_ZeroLengthArray() public {
        IKeyExchange.Bid[] memory bids = new IKeyExchange.Bid[](0);

        hoax(users.bob.account);
        vm.expectRevert(IKeyExchange.ZeroLengthArray.selector);
        keyExchange.cancelBids(bids);
    }

    function testCannot_CancelBids_CallerNotMaker() public {
        IKeyExchange.Bid[] memory bids = new IKeyExchange.Bid[](1);
        bids[0] = getGenericBid(users.bob.account);

        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.CallerNotMaker.selector);
        keyExchange.cancelBids(bids);
    }

    function testCannot_CancelBids_InvalidBidStatus() public {
        IKeyExchange.Bid[] memory bids = new IKeyExchange.Bid[](1);
        bids[0] = getGenericBid(users.bob.account);

        startHoax(users.bob.account);
        keyExchange.cancelBids(bids);
        vm.expectRevert(IKeyExchange.InvalidBidStatus.selector);
        keyExchange.cancelBids(bids);
    }

    function test_ExecuteBuyBack() public setKeyTerms(IKeyExchange.MarketType.BUYOUT) {
        address[] memory holders = getHolders(keySupply);
        uint256[] memory amounts = getAmounts(keySupply);

        /// Transfer 1 key to each of the holders.
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];

            hoax(users.admin);
            kycRegistry.modifyAccessType(holder, IKYCRegistry.AccessType.UNRESTRICTED);

            hoax(users.alice.account);
            keys.safeTransferFrom(users.alice.account, holder, keyId, 1, "");
            assertEq(keys.balanceOf(holder, keyId), 1);
        }

        assertEq(keys.balanceOf(users.alice.account, keyId), 0);

        uint256 buyBackCost = keyExchange.keyTerms(keyId).buyBack;
        uint256 totalCost = keySupply * buyBackCost;

        hoax(users.alice.account);
        keyExchange.executeBuyBack{ value: totalCost }(keyId, holders, amounts);
        assertEq(keys.balanceOf(users.alice.account, keyId), keySupply);

        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];

            assertEq(keys.balanceOf(holder, keyId), 0);
            assertEq(holder.balance, buyBackCost);
        }
    }

    function testCannot_ExecuteBuyBack_CallerNotKeyCreator() public setKeyTerms(IKeyExchange.MarketType.BUYOUT) {
        address[] memory holders = getHolders(keySupply);
        uint256[] memory amounts = getAmounts(keySupply);

        uint256 buyBackCost = keyExchange.keyTerms(keyId).buyBack;
        uint256 totalCost = keySupply * buyBackCost;

        hoax(users.eve.account);
        vm.expectRevert(IKeyExchange.CallerNotKeyCreator.selector);
        keyExchange.executeBuyBack{ value: totalCost }(keyId, holders, amounts);
    }

    function testCannot_ExecuteBuyBack_ZeroLengthArray() public setKeyTerms(IKeyExchange.MarketType.BUYOUT) {
        address[] memory holders = getHolders(0);
        uint256[] memory amounts = getAmounts(0);

        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.ZeroLengthArray.selector);
        keyExchange.executeBuyBack(keyId, holders, amounts);
    }

    function testCannot_ExecuteBuyBack_ArrayLengthMismatch() public setKeyTerms(IKeyExchange.MarketType.BUYOUT) {
        address[] memory holders = getHolders(1);
        uint256[] memory amounts = getAmounts(2);

        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.ArrayLengthMismatch.selector);
        keyExchange.executeBuyBack(keyId, holders, amounts);
    }

    function testCannot_ExecuteBuyBack_KeyNotBuyOutMarket() public setKeyTerms(IKeyExchange.MarketType.FREE) {
        address[] memory holders = getHolders(keySupply);
        uint256[] memory amounts = getAmounts(keySupply);

        uint256 buyBackCost = keyExchange.keyTerms(keyId).buyBack;
        uint256 totalCost = keySupply * buyBackCost;

        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.KeyNotBuyOutMarket.selector);
        keyExchange.executeBuyBack{ value: totalCost }(keyId, holders, amounts);
    }

    function testCannot_ExecuteBuyBack_InvalidNativeTokenAmount() public setKeyTerms(IKeyExchange.MarketType.BUYOUT) {
        address[] memory holders = getHolders(keySupply);
        uint256[] memory amounts = getAmounts(keySupply);

        /// Transfer 1 key to each of the holders.
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];

            hoax(users.admin);
            kycRegistry.modifyAccessType(holder, IKYCRegistry.AccessType.UNRESTRICTED);

            hoax(users.alice.account);
            keys.safeTransferFrom(users.alice.account, holder, keyId, 1, "");
            assertEq(keys.balanceOf(holder, keyId), 1);
        }

        uint256 buyBackCost = keyExchange.keyTerms(keyId).buyBack;
        uint256 totalCost = keySupply * buyBackCost;

        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.InvalidNativeTokenAmount.selector);
        keyExchange.executeBuyBack{ value: totalCost - 1 wei }(keyId, holders, amounts);
    }

    function testCannot_ExecuteBuyBack_InvalidNativeTokenAmount_Excess()
        public
        setKeyTerms(IKeyExchange.MarketType.BUYOUT)
    {
        address[] memory holders = getHolders(keySupply);
        uint256[] memory amounts = getAmounts(keySupply);

        /// Transfer 1 key to each of the holders.
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];

            hoax(users.admin);
            kycRegistry.modifyAccessType(holder, IKYCRegistry.AccessType.UNRESTRICTED);

            hoax(users.alice.account);
            keys.safeTransferFrom(users.alice.account, holder, keyId, 1, "");
            assertEq(keys.balanceOf(holder, keyId), 1);
        }

        uint256 buyBackCost = keyExchange.keyTerms(keyId).buyBack;
        uint256 totalCost = keySupply * buyBackCost;

        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.InvalidNativeTokenAmount.selector);
        keyExchange.executeBuyBack{ value: totalCost + 1 wei }(keyId, holders, amounts);
    }

    function testCannot_ExecuteBuyBack_NativeTransferFailed() public setKeyTerms(IKeyExchange.MarketType.BUYOUT) {
        address[] memory holders = getHolders(keySupply);
        uint256[] memory amounts = getAmounts(keySupply);

        /// Transfer 1 key to each of the holders.
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];

            hoax(users.admin);
            kycRegistry.modifyAccessType(holder, IKYCRegistry.AccessType.UNRESTRICTED);

            hoax(users.alice.account);
            keys.safeTransferFrom(users.alice.account, holder, keyId, 1, "");
            assertEq(keys.balanceOf(holder, keyId), 1);
        }

        uint256 buyBackCost = keyExchange.keyTerms(keyId).buyBack;
        uint256 totalCost = keySupply * buyBackCost;

        /// Revert the call made to the first holder.
        vm.mockCallRevert({ callee: holders[0], msgValue: buyBackCost, data: "", revertData: "" });

        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.NativeTransferFailed.selector);
        keyExchange.executeBuyBack{ value: totalCost }(keyId, holders, amounts);
    }

    function testCannot_ExecuteBuyBack_BuyBackFailed() public setKeyTerms(IKeyExchange.MarketType.BUYOUT) {
        address[] memory holders = getHolders(keySupply);
        uint256[] memory amounts = getAmounts(keySupply);

        /// Transfer 1 key to each of the holders.
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];

            hoax(users.admin);
            kycRegistry.modifyAccessType(holder, IKYCRegistry.AccessType.UNRESTRICTED);

            hoax(users.alice.account);
            keys.safeTransferFrom(users.alice.account, holder, keyId, 1, "");
            assertEq(keys.balanceOf(holder, keyId), 1);
        }

        holders = getHolders(99);
        amounts = getAmounts(99);

        uint256 buyBackCost = keyExchange.keyTerms(keyId).buyBack;
        uint256 totalCost = keySupply * buyBackCost - buyBackCost;

        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.BuyBackFailed.selector);
        keyExchange.executeBuyBack{ value: totalCost }(keyId, holders, amounts);
    }

    function test_BuyAtReserve_Fuzzed(uint256 holderCount) public setKeyTerms(IKeyExchange.MarketType.BUYOUT) {
        holderCount = bound(holderCount, 1, 50);

        address[] memory holders = getHolders(holderCount);
        uint256[] memory amounts = getAmounts(holderCount);

        /// KYC holders and transfer a single key to each of them.
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];

            hoax(users.admin);
            kycRegistry.modifyAccessType(holder, IKYCRegistry.AccessType.UNRESTRICTED);

            hoax(users.alice.account);
            keys.safeTransferFrom(users.alice.account, holder, keyId, 1, "");
            assertEq(keys.balanceOf(holder, keyId), 1);
            assertEq(holder.balance, 0 ether);
        }

        /// Calculate the expected cost of the action in native token and the protocol fee.
        uint256 reservePrice = keyExchange.keyTerms(keyId).reserve;
        uint256 expectedTotal = reservePrice * holderCount;

        /// Buy a key from each of the holders at the reserve price as Bob.
        hoax(users.bob.account, expectedTotal);
        keyExchange.buyAtReserve{ value: expectedTotal }(keyId, holders, amounts);

        /// Ensure the transfer of key and ETH was as expected.
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];

            assertEq(keys.balanceOf(holder, keyId), 0);
            assertEq(holder.balance, reservePrice);
        }

        assertEq(keys.balanceOf(users.bob.account, keyId), holderCount);
        assertEq(users.bob.account.balance, 0 ether);
    }

    function testCannot_BuyAtReserve_ZeroLengthArray() public {
        address[] memory holders = getHolders(0);
        uint256[] memory amounts = getAmounts(0);

        hoax(users.bob.account);
        vm.expectRevert(IKeyExchange.ZeroLengthArray.selector);
        keyExchange.buyAtReserve(keyId, holders, amounts);
    }

    function testCannot_BuyAtReserve_ArrayLengthMismatch() public {
        address[] memory holders = getHolders(1);
        uint256[] memory amounts = getAmounts(2);

        hoax(users.bob.account);
        vm.expectRevert(IKeyExchange.ArrayLengthMismatch.selector);
        keyExchange.buyAtReserve(keyId, holders, amounts);
    }

    function testCannot_BuyAtReserve_KeyNotBuyOutMarket() public setKeyTerms(IKeyExchange.MarketType.FREE) {
        address[] memory holders = getHolders(1);
        uint256[] memory amounts = getAmounts(1);

        hoax(users.bob.account);
        vm.expectRevert(IKeyExchange.KeyNotBuyOutMarket.selector);
        keyExchange.buyAtReserve(keyId, holders, amounts);
    }

    function testCannot_BuyAtReserve_NativeTransferFailed() public setKeyTerms(IKeyExchange.MarketType.BUYOUT) {
        address[] memory holders = getHolders(keySupply);
        uint256[] memory amounts = getAmounts(keySupply);

        /// KYC holders and transfer a single key to each of them.
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];

            hoax(users.admin);
            kycRegistry.modifyAccessType(holder, IKYCRegistry.AccessType.UNRESTRICTED);

            hoax(users.alice.account);
            keys.safeTransferFrom(users.alice.account, holder, keyId, 1, "");
            assertEq(keys.balanceOf(holder, keyId), 1);
            assertEq(holder.balance, 0 ether);
        }

        /// Calculate the expected cost of the action in native token and the protocol fee.
        uint256 reservePrice = keyExchange.keyTerms(keyId).reserve;
        uint256 expectedTotal = reservePrice * keySupply;

        /// Revert the call made to the first holder.
        vm.mockCallRevert({ callee: holders[0], msgValue: reservePrice, data: "", revertData: "" });

        /// Buy a key from each of the holders at the reserve price as Bob.
        hoax(users.bob.account, expectedTotal);
        vm.expectRevert(IKeyExchange.NativeTransferFailed.selector);
        keyExchange.buyAtReserve{ value: expectedTotal }(keyId, holders, amounts);
    }

    function testCannot_BuyAtReserve_InvalidNativeTokenAmount() public setKeyTerms(IKeyExchange.MarketType.BUYOUT) {
        address[] memory holders = getHolders(keySupply);
        uint256[] memory amounts = getAmounts(keySupply);

        /// KYC holders and transfer a single key to each of them.
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];

            hoax(users.admin);
            kycRegistry.modifyAccessType(holder, IKYCRegistry.AccessType.UNRESTRICTED);

            hoax(users.alice.account);
            keys.safeTransferFrom(users.alice.account, holder, keyId, 1, "");

            assertEq(keys.balanceOf(holder, keyId), 1);
            assertEq(holder.balance, 0 ether);
        }

        uint256 reservePrice = keyExchange.keyTerms(keyId).reserve;
        uint256 badMinAmount = reservePrice * keySupply - 1 wei;
        uint256 badMaxAmount = reservePrice * keySupply + 1 wei;

        startHoax(users.bob.account);

        /// Reverts during iteration before logic attempts to subtract a value greater than itself.
        vm.expectRevert(IKeyExchange.InvalidNativeTokenAmount.selector);
        keyExchange.buyAtReserve{ value: badMinAmount }(keyId, holders, amounts);

        /// Reverts during at end of function.
        vm.expectRevert(IKeyExchange.InvalidNativeTokenAmount.selector);
        keyExchange.buyAtReserve{ value: badMaxAmount }(keyId, holders, amounts);
    }

    function test_SetKeyTerms_FreeMarket() public {
        IKeyExchange.MarketType marketType = IKeyExchange.MarketType.FREE;

        hoax(users.alice.account);
        keyExchange.setKeyTerms(keyId, IKeyExchange.KeyTerms(marketType, 0, 0));

        IKeyExchange.KeyTerms memory terms = keyExchange.keyTerms(keyId);
        assertEq(terms.market, marketType);
        assertEq(terms.buyBack, 0 ether);
        assertEq(terms.reserve, 0 ether);
    }

    function test_SetKeyTerms_BuyOutMarket() public {
        IKeyExchange.MarketType marketType = IKeyExchange.MarketType.BUYOUT;

        hoax(users.alice.account);
        keyExchange.setKeyTerms(keyId, IKeyExchange.KeyTerms(marketType, defaultBuyBackPrice, defaultReservePrice));

        IKeyExchange.KeyTerms memory terms = keyExchange.keyTerms(keyId);
        assertEq(terms.market, marketType);
        assertEq(terms.buyBack, defaultBuyBackPrice);
        assertEq(terms.reserve, defaultReservePrice);
    }

    function testCannot_SetKeyTerms_CallerNotKeyCreator() public {
        hoax(users.eve.account);
        vm.expectRevert(IKeyExchange.CallerNotKeyCreator.selector);
        keyExchange.setKeyTerms(keyId, IKeyExchange.KeyTerms(IKeyExchange.MarketType.FREE, 0, 0));
    }

    function testCannot_SetKeyTerms_InvalidMarketType() public {
        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.InvalidMarketType.selector);
        keyExchange.setKeyTerms(keyId, IKeyExchange.KeyTerms(IKeyExchange.MarketType.UNDEFINED, 0, 0));
    }

    function testCannot_SetKeyTerms_KeyTermsDefined() public {
        IKeyExchange.MarketType marketType = IKeyExchange.MarketType.FREE;

        startHoax(users.alice.account);
        keyExchange.setKeyTerms(keyId, IKeyExchange.KeyTerms(marketType, 0, 0));
        vm.expectRevert(IKeyExchange.KeyTermsDefined.selector);
        keyExchange.setKeyTerms(keyId, IKeyExchange.KeyTerms(marketType, 0, 0));
    }

    function testCannot_SetKeyTerms_InvalidFreeMarketTerms() public {
        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.InvalidFreeMarketTerms.selector);
        keyExchange.setKeyTerms(keyId, IKeyExchange.KeyTerms(IKeyExchange.MarketType.FREE, 1, 1));
    }

    function testCannot_SetKeyTerms_InvalidBuyOutTerms() public {
        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.InvalidBuyOutTerms.selector);
        keyExchange.setKeyTerms(keyId, IKeyExchange.KeyTerms(IKeyExchange.MarketType.BUYOUT, 0, 0));
    }

    function testCannot_SetKeyTerms_BuyBackExceedsReserve() public {
        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.BuyBackExceedsReserve.selector);
        keyExchange.setKeyTerms(keyId, IKeyExchange.KeyTerms(IKeyExchange.MarketType.BUYOUT, 2, 1));
    }

    function test_ToggleMultiKeyTrading() public {
        bool initialState = keyExchange.multiKeysTradable();
        assertFalse(initialState);

        hoax(users.admin);
        keyExchange.toggleMultiKeyTrading();

        bool updatedState = keyExchange.multiKeysTradable();
        assertTrue(updatedState);
    }

    function testCannot_ToggleMultiKeyTrading_Unauthorized() public {
        hoax(users.eve.account);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        keyExchange.toggleMultiKeyTrading();
    }

    function test_SetProtocolFee_Fuzzed(uint256 newFee) public {
        newFee = bound(newFee, 1, 10_000);

        hoax(users.admin);
        keyExchange.setProtocolFee(newFee);

        assertEq(keyExchange.protocolFee(), newFee);
    }

    function testCannot_SetProtocolFee_Unauthorized() public {
        hoax(users.eve.account);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        keyExchange.setProtocolFee(0);
    }

    function testCannot_SetProtocolFee_FeeExceedsBps_Fuzzed(uint256 newFee) public {
        newFee = bound(newFee, 10_001, type(uint256).max);

        hoax(users.admin);
        vm.expectRevert(IKeyExchange.FeeExceedsBps.selector);
        keyExchange.setProtocolFee(newFee);
    }

    function test_SetFeeReceiver_Fuzzed(address newFeeReceiver) public {
        hoax(users.admin);
        keyExchange.setFeeReceiver(newFeeReceiver);
        assertEq(keyExchange.feeReceiver(), newFeeReceiver);
    }

    function testCannot_SetFeeReceiver_Unauthorized() public {
        hoax(users.eve.account);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        keyExchange.setFeeReceiver(users.eve.account);
    }

    function test_IncrementNonce_Fuzzed(address account) public {
        uint256 initialNonce = keyExchange.getNonce(account);
        assertEq(initialNonce, 0);

        hoax(account);
        keyExchange.incrementNonce();

        uint256 updatedNonce = keyExchange.getNonce(account);
        assertGt(updatedNonce, initialNonce);

        uint256 predictedNonce = initialNonce + 1;
        assertTrue(updatedNonce != predictedNonce);
    }

    function test_NameAndVersion() public {
        (string memory name, string memory version) = keyExchange.nameAndVersion();
        assertEq(name, "Key Exchange");
        assertEq(version, "1.0");
    }

    /// Helper Functions

    function getGenericOrder(address orderMaker) internal view returns (IKeyExchange.Order memory) {
        return IKeyExchange.Order({
            price: defaultOrderPrice,
            maker: orderMaker,
            taker: address(0),
            keyId: keyId,
            amount: defaultOrderAmount,
            nonce: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + 7 days
        });
    }

    function getGenericBid(address bidMaker) public view returns (IKeyExchange.Bid memory) {
        return IKeyExchange.Bid({
            maker: bidMaker,
            price: defaultBidPrice,
            keyId: keyId,
            amount: defaultBidAmount,
            nonce: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + 7 days
        });
    }

    function signOrder(IKeyExchange.Order memory order, uint256 privateKey)
        internal
        view
        returns (IKeyExchange.OrderParams memory)
    {
        bytes32 orderHash = keyExchange.hashOrder(order);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, orderHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        return IKeyExchange.OrderParams(order, signature);
    }

    function signBid(IKeyExchange.Bid memory bid, uint256 privateKey)
        internal
        view
        returns (IKeyExchange.BidParams memory)
    {
        bytes32 bidHash = keyExchange.hashBid(bid);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, bidHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        return IKeyExchange.BidParams(bid, signature);
    }
}
