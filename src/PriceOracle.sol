// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title PriceOracle
/// @notice On-chain price oracle on Arc Testnet.
/// @dev Owner (or authorized feeders) submit price data for assets.
///      Consumers can read latest prices and check staleness.
contract PriceOracle {
    address public owner;

    struct PriceFeed {
        string symbol;
        uint256 price;
        uint256 decimals;
        uint256 updatedAt;
        uint256 roundId;
        bool active;
    }

    mapping(bytes32 => PriceFeed) public feeds;
    mapping(address => bool) public authorizedFeeders;
    bytes32[] private feedKeys;

    uint256 public constant MAX_STALENESS = 1 hours;

    event PriceUpdated(bytes32 indexed key, string symbol, uint256 price, uint256 roundId);
    event FeederAuthorized(address indexed feeder);
    event FeederRevoked(address indexed feeder);
    event FeedCreated(bytes32 indexed key, string symbol, uint256 decimals);

    error NotOwner();
    error NotAuthorized();
    error FeedNotFound();
    error FeedAlreadyExists();
    error StalePrice();
    error InvalidPrice();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyFeeder() {
        if (!authorizedFeeders[msg.sender] && msg.sender != owner) revert NotAuthorized();
        _;
    }

    constructor() {
        owner = msg.sender;
        authorizedFeeders[msg.sender] = true;
    }

    /// @notice Create a new price feed for an asset.
    function createFeed(string memory symbol, uint256 decimals) external onlyOwner returns (bytes32 key) {
        key = keccak256(abi.encodePacked(symbol));
        if (feeds[key].active) revert FeedAlreadyExists();
        feeds[key] = PriceFeed(symbol, 0, decimals, 0, 0, true);
        feedKeys.push(key);
        emit FeedCreated(key, symbol, decimals);
    }

    /// @notice Submit a new price for an existing feed.
    function updatePrice(string memory symbol, uint256 price) external onlyFeeder {
        if (price == 0) revert InvalidPrice();
        bytes32 key = keccak256(abi.encodePacked(symbol));
        PriceFeed storage feed = feeds[key];
        if (!feed.active) revert FeedNotFound();
        feed.price = price;
        feed.updatedAt = block.timestamp;
        feed.roundId++;
        emit PriceUpdated(key, symbol, price, feed.roundId);
    }

    /// @notice Get latest price — reverts if stale.
    function getPrice(string memory symbol) external view returns (uint256 price, uint256 updatedAt, uint256 roundId) {
        bytes32 key = keccak256(abi.encodePacked(symbol));
        PriceFeed memory feed = feeds[key];
        if (!feed.active) revert FeedNotFound();
        if (feed.updatedAt == 0 || block.timestamp - feed.updatedAt > MAX_STALENESS) revert StalePrice();
        return (feed.price, feed.updatedAt, feed.roundId);
    }

    /// @notice Get latest price without staleness check.
    function getPriceUnsafe(string memory symbol)
        external
        view
        returns (uint256 price, uint256 updatedAt, uint256 roundId)
    {
        bytes32 key = keccak256(abi.encodePacked(symbol));
        PriceFeed memory feed = feeds[key];
        if (!feed.active) revert FeedNotFound();
        return (feed.price, feed.updatedAt, feed.roundId);
    }

    /// @notice Authorize a new price feeder.
    function authorizeFeeder(address feeder) external onlyOwner {
        authorizedFeeders[feeder] = true;
        emit FeederAuthorized(feeder);
    }

    /// @notice Revoke a price feeder.
    function revokeFeeder(address feeder) external onlyOwner {
        authorizedFeeders[feeder] = false;
        emit FeederRevoked(feeder);
    }

    /// @notice Returns total number of feeds.
    function feedCount() external view returns (uint256) {
        return feedKeys.length;
    }
}
