// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../src/PriceOracle.sol";

contract PriceOracleTest is Test {
    PriceOracle public oracle;
    address public owner = address(this);
    address public feeder = address(0xFEED);
    address public alice = address(0xA11CE);

    function setUp() public {
        oracle = new PriceOracle();
        oracle.createFeed("BTC", 8);
        oracle.createFeed("ETH", 8);
    }

    function testCreateFeed() public view {
        bytes32 key = keccak256(abi.encodePacked("BTC"));
        (string memory symbol,, uint256 decimals,,, bool active) = oracle.feeds(key);
        assertEq(symbol, "BTC");
        assertEq(decimals, 8);
        assertEq(active, true);
        assertEq(oracle.feedCount(), 2);
    }

    function testCreateFeedAlreadyExistsReverts() public {
        vm.expectRevert(PriceOracle.FeedAlreadyExists.selector);
        oracle.createFeed("BTC", 8);
    }

    function testUpdatePrice() public {
        oracle.updatePrice("BTC", 65000_00000000);
        (uint256 price, uint256 updatedAt, uint256 roundId) = oracle.getPriceUnsafe("BTC");
        assertEq(price, 65000_00000000);
        assertEq(roundId, 1);
        assertGt(updatedAt, 0);
    }

    function testUpdatePriceZeroReverts() public {
        vm.expectRevert(PriceOracle.InvalidPrice.selector);
        oracle.updatePrice("BTC", 0);
    }

    function testGetPriceFreshData() public {
        oracle.updatePrice("BTC", 65000_00000000);
        (uint256 price,,) = oracle.getPrice("BTC");
        assertEq(price, 65000_00000000);
    }

    function testGetPriceStalePriceReverts() public {
        oracle.updatePrice("BTC", 65000_00000000);
        vm.warp(block.timestamp + 2 hours);
        vm.expectRevert(PriceOracle.StalePrice.selector);
        oracle.getPrice("BTC");
    }

    function testGetPriceNeverUpdatedReverts() public {
        vm.expectRevert(PriceOracle.StalePrice.selector);
        oracle.getPrice("BTC");
    }

    function testGetPriceFeedNotFoundReverts() public {
        vm.expectRevert(PriceOracle.FeedNotFound.selector);
        oracle.getPrice("DOGE");
    }

    function testAuthorizeFeeder() public {
        oracle.authorizeFeeder(feeder);
        assertTrue(oracle.authorizedFeeders(feeder));
        vm.prank(feeder);
        oracle.updatePrice("BTC", 66000_00000000);
        (uint256 price,,) = oracle.getPriceUnsafe("BTC");
        assertEq(price, 66000_00000000);
    }

    function testRevokeFeeder() public {
        oracle.authorizeFeeder(feeder);
        oracle.revokeFeeder(feeder);
        assertFalse(oracle.authorizedFeeders(feeder));
        vm.prank(feeder);
        vm.expectRevert(PriceOracle.NotAuthorized.selector);
        oracle.updatePrice("BTC", 66000_00000000);
    }

    function testUnauthorizedFeederReverts() public {
        vm.prank(alice);
        vm.expectRevert(PriceOracle.NotAuthorized.selector);
        oracle.updatePrice("BTC", 65000_00000000);
    }

    function testMultipleRounds() public {
        oracle.updatePrice("BTC", 65000_00000000);
        oracle.updatePrice("BTC", 66000_00000000);
        oracle.updatePrice("BTC", 67000_00000000);
        (,, uint256 roundId) = oracle.getPriceUnsafe("BTC");
        assertEq(roundId, 3);
    }

    function testMultipleFeeds() public {
        oracle.updatePrice("BTC", 65000_00000000);
        oracle.updatePrice("ETH", 3500_00000000);
        (uint256 btcPrice,,) = oracle.getPriceUnsafe("BTC");
        (uint256 ethPrice,,) = oracle.getPriceUnsafe("ETH");
        assertEq(btcPrice, 65000_00000000);
        assertEq(ethPrice, 3500_00000000);
    }

    function testOnlyOwnerCreateFeed() public {
        vm.prank(alice);
        vm.expectRevert(PriceOracle.NotOwner.selector);
        oracle.createFeed("SOL", 8);
    }
}
