// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./BaseTest.sol";

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

        /// For ease of testing, allow restricted users to trade.
        startHoax(users.admin);
        keyExchange.toggleAllowRestrictedUsers();
        vm.stopPrank();
    }

    function testCannotDeploy_Admin_ZeroAddressInvalid() public {
        vm.expectRevert(IKeyExchange.ZeroAddressInvalid.selector);
        new KeyExchange({
            admin_: address(0),
            feeReceiver_: FEE_RECEIVER,
            weth_: address(mockWETH),
            keys_: keys,
            accessRegistry_: accessRegistry
        });
    }

    function testCannotDeploy_FeeReceiver_ZeroAddressInvalid() public {
        vm.expectRevert(IKeyExchange.ZeroAddressInvalid.selector);
        new KeyExchange({
            admin_: users.admin,
            feeReceiver_: address(0),
            weth_: address(mockWETH),
            keys_: keys,
            accessRegistry_: accessRegistry
        });
    }

    function testCannotDeploy_WETH_ZeroAddressInvalid() public {
        vm.expectRevert(IKeyExchange.ZeroAddressInvalid.selector);
        new KeyExchange({
            admin_: users.admin,
            feeReceiver_: FEE_RECEIVER,
            weth_: address(0),
            keys_: keys,
            accessRegistry_: accessRegistry
        });
    }

    function testCannotDeploy_Keys_ZeroAddressInvalid() public {
        vm.expectRevert(IKeyExchange.ZeroAddressInvalid.selector);
        new KeyExchange({
            admin_: users.admin,
            feeReceiver_: FEE_RECEIVER,
            weth_: address(mockWETH),
            keys_: IKeys(address(0)),
            accessRegistry_: accessRegistry
        });
    }

    function testCannotDeploy_AccessRegistry_ZeroAddressInvalid() public {
        vm.expectRevert(IKeyExchange.ZeroAddressInvalid.selector);
        new KeyExchange({
            admin_: users.admin,
            feeReceiver_: FEE_RECEIVER,
            weth_: address(mockWETH),
            keys_: keys,
            accessRegistry_: IAccessRegistry(address(0))
        });
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

        uint256 expectedFee = order.price * order.protocolFee / 10_000;
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

        uint256 expectedFee = order.price * order.protocolFee / 10_000;
        uint256 expectedEarnings = order.price - expectedFee;

        assertEq(users.alice.account.balance, initialMakerBalance + expectedEarnings);
        assertEq(users.bob.account.balance, excess);
        assertEq(keyExchange.feeReceiver().balance, initialFeeBalance + expectedFee);
    }

    function test_ExecuteOrders_AfterFeeChange() public setKeyTerms(IKeyExchange.MarketType.FREE) {
        IKeyExchange.Order memory order = getGenericOrder(users.alice.account);
        bytes32 orderHash = keyExchange.hashOrder(order);

        IKeyExchange.OrderParams[] memory orders = new IKeyExchange.OrderParams[](1);
        orders[0] = signOrder(order, users.alice.privateKey);

        assertEq(keyExchange.orderStatus(orderHash), IKeyExchange.Status.OPEN);
        assertEq(keys.balanceOf(users.alice.account, order.keyId), keySupply);
        assertEq(keys.balanceOf(users.bob.account, order.keyId), 0);

        uint256 initialMakerBalance = users.alice.account.balance;
        uint256 initialFeeBalance = keyExchange.feeReceiver().balance;

        /// Change protocol fee after the order has been signed.
        hoax(users.admin);
        keyExchange.setProtocolFee({ newProtocolFee: 1_000 }); // 10.00%

        hoax(users.bob.account, order.price);
        vm.expectEmit({ checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true });
        emit OrderFilled({ orderHash: orderHash });
        keyExchange.executeOrders{ value: order.price }(orders);

        assertEq(keyExchange.orderStatus(orderHash), IKeyExchange.Status.FILLED);
        assertEq(keys.balanceOf(users.alice.account, order.keyId), keySupply - order.amount);
        assertEq(keys.balanceOf(users.bob.account, order.keyId), order.amount);

        uint256 expectedFee = order.price * order.protocolFee / 10_000;
        uint256 expectedEarnings = order.price - expectedFee;

        assertEq(users.alice.account.balance, initialMakerBalance + expectedEarnings);
        assertEq(users.bob.account.balance, 0);
        assertEq(keyExchange.feeReceiver().balance, initialFeeBalance + expectedFee);
    }

    function test_ExecuteOrders_WithRoyalty() public setKeyTerms(IKeyExchange.MarketType.FREE) {
        IKeyExchange.Order memory order = getGenericOrder(users.alice.account);

        /// Add a royalty payment of 2.5% to the order.
        uint256 royaltyFee = order.price * 250 / 10_000;
        order.royalties = new IKeyExchange.Royalties[](1);
        order.royalties[0].receiver = users.eve.account;
        order.royalties[0].fee = royaltyFee;
        uint256 expectedBalanceWithRoyalty = users.eve.account.balance + royaltyFee;

        bytes32 orderHash = keyExchange.hashOrder(order);

        IKeyExchange.OrderParams[] memory orders = new IKeyExchange.OrderParams[](1);
        orders[0] = signOrder(order, users.alice.privateKey);

        assertEq(keyExchange.orderStatus(orderHash), IKeyExchange.Status.OPEN);
        assertEq(keys.balanceOf(users.alice.account, order.keyId), keySupply);
        assertEq(keys.balanceOf(users.bob.account, order.keyId), 0);

        uint256 initialMakerBalance = users.alice.account.balance;
        uint256 initialFeeBalance = keyExchange.feeReceiver().balance;

        /// Change protocol fee after the order has been signed.
        hoax(users.admin);
        keyExchange.setProtocolFee({ newProtocolFee: 1_000 }); // 10.00%

        hoax(users.bob.account, order.price);
        vm.expectEmit({ checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true });
        emit OrderFilled({ orderHash: orderHash });
        keyExchange.executeOrders{ value: order.price }(orders);

        assertEq(keyExchange.orderStatus(orderHash), IKeyExchange.Status.FILLED);
        assertEq(keys.balanceOf(users.alice.account, order.keyId), keySupply - order.amount);
        assertEq(keys.balanceOf(users.bob.account, order.keyId), order.amount);

        uint256 expectedFee = order.price * order.protocolFee / 10_000;
        uint256 expectedEarnings = order.price - expectedFee - royaltyFee;

        assertEq(users.alice.account.balance, initialMakerBalance + expectedEarnings);
        assertEq(users.bob.account.balance, 0);
        assertEq(keyExchange.feeReceiver().balance, initialFeeBalance + expectedFee);
        assertEq(users.eve.account.balance, expectedBalanceWithRoyalty);
    }

    function testCannot_ExecuteOrders_ZeroLengthArray() public {
        IKeyExchange.OrderParams[] memory orders = new IKeyExchange.OrderParams[](0);

        hoax(users.bob.account);
        vm.expectRevert(IKeyExchange.ZeroLengthArray.selector);
        keyExchange.executeOrders(orders);
    }

    function testCannot_ExecuteOrders_InvalidKeyMarket() public {
        IKeyExchange.Order memory order = getGenericOrder(users.alice.account);
        IKeyExchange.OrderParams[] memory orders = new IKeyExchange.OrderParams[](1);
        orders[0] = signOrder(order, users.alice.privateKey);

        hoax(users.bob.account);
        vm.expectRevert(IKeyExchange.InvalidKeyMarket.selector);
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

        uint256 expectedFee = order.price * order.protocolFee / 10_000;
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

        uint256 expectedFee = bid.price * bid.protocolFee / 10_000;
        uint256 expectedEarnings = bid.price - expectedFee;

        assertEq(mockWETH.balanceOf(users.alice.account), expectedEarnings);
        assertEq(mockWETH.balanceOf(users.bob.account), 0);
        assertEq(mockWETH.balanceOf(keyExchange.feeReceiver()), expectedFee);
    }

    function test_ExecuteBids_WithRoyalty() public setKeyTerms(IKeyExchange.MarketType.FREE) {
        IKeyExchange.Bid memory bid = getGenericBid(users.bob.account);

        /// Add royalty payment of 2.50% to the bid.
        uint256 royaltyFee = bid.price * 250 / 10_000;
        bid.royalties = new IKeyExchange.Royalties[](1);
        bid.royalties[0].receiver = users.eve.account;
        bid.royalties[0].fee = royaltyFee;

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

        uint256 expectedFee = bid.price * bid.protocolFee / 10_000;
        uint256 expectedEarnings = bid.price - expectedFee - royaltyFee;

        assertEq(mockWETH.balanceOf(users.alice.account), expectedEarnings);
        assertEq(mockWETH.balanceOf(users.bob.account), 0);
        assertEq(mockWETH.balanceOf(keyExchange.feeReceiver()), expectedFee);
        assertEq(mockWETH.balanceOf(users.eve.account), royaltyFee);
    }

    function test_ExecuteBids_WithRoyalties() public setKeyTerms(IKeyExchange.MarketType.FREE) {
        IKeyExchange.Bid memory bid = getGenericBid(users.bob.account);

        /// Add two royalty payments of 2.50% to the bid.
        uint256 royaltyFee = bid.price * 250 / 10_000;
        uint256 expectedRoyaltyFee = royaltyFee * 2;
        bid.royalties = new IKeyExchange.Royalties[](2);
        bid.royalties[0].receiver = users.eve.account;
        bid.royalties[0].fee = royaltyFee;
        bid.royalties[1].receiver = users.eve.account;
        bid.royalties[1].fee = royaltyFee;

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

        uint256 expectedFee = bid.price * bid.protocolFee / 10_000;
        uint256 expectedEarnings = bid.price - expectedFee - expectedRoyaltyFee;

        assertEq(mockWETH.balanceOf(users.alice.account), expectedEarnings);
        assertEq(mockWETH.balanceOf(users.bob.account), 0);
        assertEq(mockWETH.balanceOf(keyExchange.feeReceiver()), expectedFee);
        assertEq(mockWETH.balanceOf(users.eve.account), expectedRoyaltyFee);
    }

    function testCannot_ExecuteBids_ZeroLengthArray() public {
        IKeyExchange.BidParams[] memory bids = new IKeyExchange.BidParams[](0);

        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.ZeroLengthArray.selector);
        keyExchange.executeBids(bids);
    }

    function testCannot_ExecuteBids_InvalidKeyMarket() public {
        IKeyExchange.Bid memory bid = getGenericBid(users.bob.account);
        IKeyExchange.BidParams[] memory bids = new IKeyExchange.BidParams[](1);
        bids[0] = signBid(bid, users.bob.privateKey);

        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.InvalidKeyMarket.selector);
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
        vm.expectRevert("SafeERC20: ERC20 operation did not succeed");
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

        uint256 calculatedFee = bid.price * bid.protocolFee / 10_000;
        uint256 takerEarnings = bid.price - calculatedFee;

        /// Ensure the WETH transfer of earnings to Alice fails and returns false.
        bytes4 selector = mockWETH.transferFrom.selector;
        bytes memory data = abi.encodeWithSelector(selector, bid.maker, users.alice.account, takerEarnings);
        vm.mockCall({ callee: address(mockWETH), data: data, returnData: abi.encode(false) });

        hoax(users.alice.account);
        vm.expectRevert("SafeERC20: ERC20 operation did not succeed");
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

        /// Transfer 1 key to each of the holders.
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];

            hoax(users.admin);
            accessRegistry.modifyAccessType(holder, IAccessRegistry.AccessType.UNRESTRICTED);

            hoax(users.alice.account);
            keys.safeTransferFrom(users.alice.account, holder, keyId, 1, "");
            assertEq(keys.balanceOf(holder, keyId), 1);
        }

        assertEq(keys.balanceOf(users.alice.account, keyId), 0);

        /// As the last holder, lend a key to the first holder.
        hoax(holders[99], 0 ether);
        keys.lendKeys({ lendee: holders[0], keyId: keyId, lendAmount: 1, lendDuration: 1 days });
        assertEq(keys.balanceOf({ account: holders[0], id: keyId }), 2);

        uint256 buyBackCost = keyExchange.keyTerms(keyId).buyBack;
        uint256 totalCost = keySupply * buyBackCost;

        /// Modify holders array to not include the last holder.
        address[] memory newHolders = new address[](99);
        for (uint256 i = 0; i < newHolders.length; i++) {
            newHolders[i] = holders[i];
        }

        hoax(users.alice.account);
        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: false, checkData: true });
        emit BuyOutExecuted({ caller: users.alice.account, keyId: keyId });
        keyExchange.executeBuyBack{ value: totalCost }(keyId, newHolders);

        assertEq(keys.balanceOf(users.alice.account, keyId), keySupply);

        /// Iterate through each of the original holders, ensuring the last holder has been paid the
        /// correct amount of earnings.
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];
            assertEq(keys.balanceOf(holder, keyId), 0);
            assertEq(holder.balance, buyBackCost);
        }

        IKeyExchange.KeyTerms memory keyTerms = keyExchange.keyTerms(keyId);
        assertEq(keyTerms.market, IKeyExchange.MarketType.INACTIVE);
        assertEq(keyTerms.buyBack, 0);
        assertEq(keyTerms.reserve, 0);
    }

    function test_ExecuteBuyBack_RefundsExcess() public setKeyTerms(IKeyExchange.MarketType.BUYOUT) {
        uint256 excessFunds = 69 wei;
        address[] memory holders = getHolders(keySupply);

        /// Transfer 1 key to each of the holders.
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];

            hoax(users.admin);
            accessRegistry.modifyAccessType(holder, IAccessRegistry.AccessType.UNRESTRICTED);

            hoax(users.alice.account);
            keys.safeTransferFrom(users.alice.account, holder, keyId, 1, "");
            assertEq(keys.balanceOf(holder, keyId), 1);
        }

        assertEq(keys.balanceOf(users.alice.account, keyId), 0);

        uint256 buyBackCost = keyExchange.keyTerms(keyId).buyBack;
        uint256 totalCost = keySupply * buyBackCost;

        hoax(users.alice.account, totalCost + excessFunds);
        keyExchange.executeBuyBack{ value: totalCost }(keyId, holders);
        assertEq(keys.balanceOf(users.alice.account, keyId), keySupply);

        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];

            assertEq(keys.balanceOf(holder, keyId), 0);
            assertEq(holder.balance, buyBackCost);
        }

        assertEq(users.alice.account.balance, excessFunds);
    }

    function testCannot_ExecuteBuyBack_CallerNotKeyCreator() public setKeyTerms(IKeyExchange.MarketType.BUYOUT) {
        address[] memory holders = getHolders(keySupply);
        uint256 buyBackCost = keyExchange.keyTerms(keyId).buyBack;
        uint256 totalCost = keySupply * buyBackCost;

        hoax(users.eve.account);
        vm.expectRevert(IKeyExchange.CallerNotKeyCreator.selector);
        keyExchange.executeBuyBack{ value: totalCost }(keyId, holders);
    }

    function testCannot_ExecuteBuyBack_ZeroLengthArray() public setKeyTerms(IKeyExchange.MarketType.BUYOUT) {
        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.ZeroLengthArray.selector);
        keyExchange.executeBuyBack(keyId, getHolders(0));
    }

    function testCannot_ExecuteBuyBack_KeyNotBuyOutMarket() public setKeyTerms(IKeyExchange.MarketType.FREE) {
        address[] memory holders = getHolders(keySupply);
        uint256 buyBackCost = keyExchange.keyTerms(keyId).buyBack;
        uint256 totalCost = keySupply * buyBackCost;

        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.KeyNotBuyOutMarket.selector);
        keyExchange.executeBuyBack{ value: totalCost }(keyId, holders);
    }

    function testCannot_ExecuteBuyBack_InvalidNativeTokenAmount() public setKeyTerms(IKeyExchange.MarketType.BUYOUT) {
        address[] memory holders = getHolders(keySupply);

        /// Transfer 1 key to each of the holders.
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];

            hoax(users.admin);
            accessRegistry.modifyAccessType(holder, IAccessRegistry.AccessType.UNRESTRICTED);

            hoax(users.alice.account);
            keys.safeTransferFrom(users.alice.account, holder, keyId, 1, "");
            assertEq(keys.balanceOf(holder, keyId), 1);
        }

        uint256 buyBackCost = keyExchange.keyTerms(keyId).buyBack;
        uint256 totalCost = keySupply * buyBackCost;

        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.InvalidNativeTokenAmount.selector);
        keyExchange.executeBuyBack{ value: totalCost - 1 wei }(keyId, holders);
    }

    function testCannot_ExecuteBuyBack_NativeTransferFailed() public setKeyTerms(IKeyExchange.MarketType.BUYOUT) {
        address[] memory holders = getHolders(keySupply);

        /// Transfer 1 key to each of the holders.
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];

            hoax(users.admin);
            accessRegistry.modifyAccessType(holder, IAccessRegistry.AccessType.UNRESTRICTED);

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
        keyExchange.executeBuyBack{ value: totalCost }(keyId, holders);
    }

    function testCannot_ExecuteBuyBack_BuyBackFailed() public setKeyTerms(IKeyExchange.MarketType.BUYOUT) {
        address[] memory holders = getHolders(keySupply);

        /// Transfer 1 key to each of the holders.
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];

            hoax(users.admin);
            accessRegistry.modifyAccessType(holder, IAccessRegistry.AccessType.UNRESTRICTED);

            hoax(users.alice.account);
            keys.safeTransferFrom(users.alice.account, holder, keyId, 1, "");
            assertEq(keys.balanceOf(holder, keyId), 1);
        }

        holders = getHolders(99);

        uint256 buyBackCost = keyExchange.keyTerms(keyId).buyBack;
        uint256 totalCost = keySupply * buyBackCost - buyBackCost;

        hoax(users.alice.account);
        vm.expectRevert(IKeyExchange.BuyBackFailed.selector);
        keyExchange.executeBuyBack{ value: totalCost }(keyId, holders);
    }

    function test_BuyAtReserve() public setKeyTerms(IKeyExchange.MarketType.BUYOUT) {
        uint256 holderCount = 100;
        address[] memory holders = getHolders(holderCount);

        /// KYC holders and transfer a single key to each of them.
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];

            hoax(users.admin);
            accessRegistry.modifyAccessType(holder, IAccessRegistry.AccessType.UNRESTRICTED);

            hoax(users.alice.account);
            keys.safeTransferFrom(users.alice.account, holder, keyId, 1, "");
            assertEq(keys.balanceOf(holder, keyId), 1);
            assertEq(holder.balance, 0 ether);
        }

        /// As the last holder, lend a key to the first holder.
        hoax(holders[99], 0 ether);
        keys.lendKeys({ lendee: holders[0], keyId: keyId, lendAmount: 1, lendDuration: 1 days });
        assertEq(keys.balanceOf({ account: holders[0], id: keyId }), 2);

        /// Modify holders array to not include the last holder.
        address[] memory newHolders = new address[](99);
        for (uint256 i = 0; i < newHolders.length; i++) {
            newHolders[i] = holders[i];
        }

        /// Calculate the expected cost of the action in native token.
        uint256 reservePrice = keyExchange.keyTerms(keyId).reserve;
        uint256 expectedTotal = reservePrice * holderCount;

        /// Buy a key from each of the holders at the reserve price as Bob.
        hoax(users.bob.account, expectedTotal);
        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: false, checkData: true });
        emit ReserveBuyOut({ caller: users.bob.account, keyId: keyId });
        keyExchange.buyAtReserve{ value: expectedTotal }(keyId, newHolders);

        /// Ensure the transfer of key and ETH was as expected.
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];

            assertEq(keys.balanceOf(holder, keyId), 0);
            assertEq(holder.balance, reservePrice);
        }

        assertEq(keys.balanceOf(users.bob.account, keyId), holderCount);
        assertEq(users.bob.account.balance, 0 ether);

        IKeyExchange.KeyTerms memory keyTerms = keyExchange.keyTerms(keyId);
        assertEq(keyTerms.market, IKeyExchange.MarketType.INACTIVE);
        assertEq(keyTerms.buyBack, 0);
        assertEq(keyTerms.reserve, 0);
    }

    function test_BuyAtReserve_RefundsExcess() public setKeyTerms(IKeyExchange.MarketType.BUYOUT) {
        uint256 excessFunds = 69 wei;
        uint256 holderCount = 100;
        address[] memory holders = getHolders(holderCount);

        /// KYC holders and transfer a single key to each of them.
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];

            hoax(users.admin);
            accessRegistry.modifyAccessType(holder, IAccessRegistry.AccessType.UNRESTRICTED);

            hoax(users.alice.account);
            keys.safeTransferFrom(users.alice.account, holder, keyId, 1, "");
            assertEq(keys.balanceOf(holder, keyId), 1);
            assertEq(holder.balance, 0 ether);
        }

        /// Calculate the expected cost of the action in native token.
        uint256 reservePrice = keyExchange.keyTerms(keyId).reserve;
        uint256 expectedTotal = reservePrice * holderCount;

        /// Buy a key from each of the holders at the reserve price as Bob.
        hoax(users.bob.account, expectedTotal + excessFunds);
        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: true });
        emit ReserveBuyOut({ caller: users.bob.account, keyId: keyId });
        keyExchange.buyAtReserve{ value: expectedTotal }(keyId, holders);

        /// Ensure the transfer of key and ETH was as expected.
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];

            assertEq(keys.balanceOf(holder, keyId), 0);
            assertEq(holder.balance, reservePrice);
        }

        assertEq(keys.balanceOf(users.bob.account, keyId), holderCount);
        assertEq(users.bob.account.balance, excessFunds);
    }

    function testCannot_BuyAtReserve_ZeroLengthArray() public {
        hoax(users.bob.account);
        vm.expectRevert(IKeyExchange.ZeroLengthArray.selector);
        keyExchange.buyAtReserve(keyId, getHolders(0));
    }

    function testCannot_BuyAtReserve_KeyNotBuyOutMarket() public setKeyTerms(IKeyExchange.MarketType.FREE) {
        hoax(users.bob.account);
        vm.expectRevert(IKeyExchange.KeyNotBuyOutMarket.selector);
        keyExchange.buyAtReserve(keyId, getHolders(1));
    }

    function testCannot_BuyAtReserve_NativeTransferFailed() public setKeyTerms(IKeyExchange.MarketType.BUYOUT) {
        address[] memory holders = getHolders(keySupply);

        /// KYC holders and transfer a single key to each of them.
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];

            hoax(users.admin);
            accessRegistry.modifyAccessType(holder, IAccessRegistry.AccessType.UNRESTRICTED);

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
        keyExchange.buyAtReserve{ value: expectedTotal }(keyId, holders);
    }

    function testCannot_BuyAtReserve_InvalidNativeTokenAmount() public setKeyTerms(IKeyExchange.MarketType.BUYOUT) {
        address[] memory holders = getHolders(keySupply);

        /// KYC holders and transfer a single key to each of them.
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];

            hoax(users.admin);
            accessRegistry.modifyAccessType(holder, IAccessRegistry.AccessType.UNRESTRICTED);

            hoax(users.alice.account);
            keys.safeTransferFrom(users.alice.account, holder, keyId, 1, "");

            assertEq(keys.balanceOf(holder, keyId), 1);
            assertEq(holder.balance, 0 ether);
        }

        uint256 reservePrice = keyExchange.keyTerms(keyId).reserve;
        uint256 badMinAmount = reservePrice * keySupply - 1 wei;

        startHoax(users.bob.account);

        /// Reverts during iteration before logic attempts to subtract a value greater than itself.
        vm.expectRevert(IKeyExchange.InvalidNativeTokenAmount.selector);
        keyExchange.buyAtReserve{ value: badMinAmount }(keyId, holders);
    }

    function testCannot_BuyAtReserve_BuyBackFailed_Fuzzed(uint256 holderCount)
        public
        setKeyTerms(IKeyExchange.MarketType.BUYOUT)
    {
        holderCount = bound(holderCount, 1, keySupply - 1);
        address[] memory holders = getHolders(holderCount);

        /// KYC holders and transfer a single key to each of them.
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];

            hoax(users.admin);
            accessRegistry.modifyAccessType(holder, IAccessRegistry.AccessType.UNRESTRICTED);

            hoax(users.alice.account);
            keys.safeTransferFrom(users.alice.account, holder, keyId, 1, "");
            assertEq(keys.balanceOf(holder, keyId), 1);
            assertEq(holder.balance, 0 ether);
        }

        /// Calculate the expected cost of the action in native token.
        uint256 reservePrice = keyExchange.keyTerms(keyId).reserve;
        uint256 expectedTotal = reservePrice * holderCount;

        /// Buy a key from each of the holders at the reserve price as Bob.
        hoax(users.bob.account, expectedTotal);
        vm.expectRevert(IKeyExchange.BuyBackFailed.selector);
        keyExchange.buyAtReserve{ value: expectedTotal }(keyId, holders);
    }

    function test_SetKeyTerms_FreeMarket() public {
        IKeyExchange.MarketType marketType = IKeyExchange.MarketType.FREE;
        IKeyExchange.KeyTerms memory keyTerms = IKeyExchange.KeyTerms(marketType, 0, 0);

        hoax(users.alice.account);
        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: false, checkData: true });
        emit KeyTermsSet({ keyId: keyId, keyTerms: keyTerms });
        keyExchange.setKeyTerms(keyId, keyTerms);

        IKeyExchange.KeyTerms memory terms = keyExchange.keyTerms(keyId);
        assertEq(terms.market, marketType);
        assertEq(terms.buyBack, 0 ether);
        assertEq(terms.reserve, 0 ether);
    }

    function test_SetKeyTerms_BuyOutMarket() public {
        IKeyExchange.MarketType marketType = IKeyExchange.MarketType.BUYOUT;
        IKeyExchange.KeyTerms memory keyTerms =
            IKeyExchange.KeyTerms(marketType, defaultBuyBackPrice, defaultReservePrice);

        hoax(users.alice.account);
        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: false, checkData: true });
        emit KeyTermsSet({ keyId: keyId, keyTerms: keyTerms });
        keyExchange.setKeyTerms(keyId, keyTerms);

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
        vm.expectEmit({ checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true });
        emit MultiKeyTradingUpdated({ newStatus: !initialState });
        keyExchange.toggleMultiKeyTrading();

        bool updatedState = keyExchange.multiKeysTradable();
        assertTrue(updatedState);
    }

    function testCannot_ToggleMultiKeyTrading_Unauthorized() public {
        hoax(users.eve.account);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        keyExchange.toggleMultiKeyTrading();
    }

    function test_ToggleAllowRestrictedUsers() public {
        /// Reset state.
        hoax(users.admin);
        keyExchange.toggleAllowRestrictedUsers();

        bool initialState = keyExchange.allowRestrictedUsers();
        assertFalse(initialState);

        hoax(users.admin);
        vm.expectEmit({ checkTopic1: true, checkTopic2: false, checkTopic3: false, checkData: true });
        emit RestrictedUserAccessUpdated({ newStatus: !initialState });
        keyExchange.toggleAllowRestrictedUsers();

        bool updatedState = keyExchange.allowRestrictedUsers();
        assertTrue(updatedState);
    }

    function testCannot_ToggleAllowRestrictedUsers_Unauthorized(address nonAdmin) public {
        vm.assume(nonAdmin != users.admin);

        hoax(nonAdmin);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        keyExchange.toggleAllowRestrictedUsers();
    }

    function test_SetProtocolFee_Fuzzed(uint256 newFee) public {
        newFee = bound(newFee, 1, 10_000);
        uint256 oldFee = keyExchange.protocolFee();

        hoax(users.admin);
        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: false, checkData: true });
        emit ProtocolFeeUpdated({ oldFee: oldFee, newFee: newFee });
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
        vm.assume(newFeeReceiver != address(0));
        address oldFeeReceiver = keyExchange.feeReceiver();

        hoax(users.admin);
        vm.expectEmit({ checkTopic1: true, checkTopic2: true, checkTopic3: false, checkData: true });
        emit FeeReceiverUpdated({ oldFeeReceiver: oldFeeReceiver, newFeeReceiver: newFeeReceiver });
        keyExchange.setFeeReceiver(newFeeReceiver);

        assertEq(keyExchange.feeReceiver(), newFeeReceiver);
    }

    function testCannot_SetFeeReceiver_Unauthorized() public {
        hoax(users.eve.account);
        vm.expectRevert(UNAUTHORIZED_SELECTOR);
        keyExchange.setFeeReceiver(users.eve.account);
    }

    function testCannot_SetFeeReceiver_ZeroAddressInvalid() public {
        hoax(users.admin);
        vm.expectRevert(IKeyExchange.ZeroAddressInvalid.selector);
        keyExchange.setFeeReceiver({ newFeeReceiver: address(0) });
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
            endTime: block.timestamp + 7 days,
            protocolFee: keyExchange.protocolFee(),
            royalties: new IKeyExchange.Royalties[](0)
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
            endTime: block.timestamp + 7 days,
            protocolFee: keyExchange.protocolFee(),
            royalties: new IKeyExchange.Royalties[](0)
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
