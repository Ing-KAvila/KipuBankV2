// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

////        Imports

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

////        Libraries

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

////        Interfaces

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

interface IERC20Metadata is IERC20 {
    function decimals() external view returns (uint8);
}

/// @title KipuBank - Multi-token vault with USD-based limits and owner control
/// @notice Allows deposits and withdrawals of ETH and ERC-20 tokens with USD-based caps
contract KipuBank is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Chainlink price feed for ETH/USD
    AggregatorV3Interface public immutable ethUsdPriceFeed;

    /// @notice Global bank cap in USD (scaled to 6 decimals)
    uint256 public immutable bankCapUsd;

    /// @notice Max withdrawal per transaction in USD (scaled to 6 decimals)
    uint256 public immutable withdrawalLimitUsd;

    /// @notice Mapping of user balances per token (address(0) = ETH)
    mapping(address => mapping(address => uint256)) public vault;

    /// @notice Total deposits per token
    mapping(address => uint256) public totalTokenDeposits;

    /// @notice Emitted when a user deposits ETH or ERC-20
    /// @param user Address of the depositor
    /// @param token Token address (address(0) for ETH)
    /// @param amount Amount deposited
    event Deposited(address indexed user, address indexed token, uint256 amount);

    /// @notice Emitted when a user withdraws ETH or ERC-20
    /// @param user Address of the withdrawer
    /// @param token Token address (address(0) for ETH)
    /// @param amount Amount withdrawn
    event Withdrawn(address indexed user, address indexed token, uint256 amount);

    /// @notice Initializes the contract with limits and Chainlink feed
/// @param _ethUsdFeed Address of Chainlink ETH/USD price feed
/// @param _bankCapUsd Global cap in USD (6 decimals)
/// @param _withdrawalLimitUsd Max withdrawal per tx in USD (6 decimals)
constructor(
    address _ethUsdFeed,
    uint256 _bankCapUsd,
    uint256 _withdrawalLimitUsd
) Ownable(msg.sender) {
    ethUsdPriceFeed = AggregatorV3Interface(_ethUsdFeed);
    bankCapUsd = _bankCapUsd;
    withdrawalLimitUsd = _withdrawalLimitUsd;
}


    /// @notice Deposit ETH into the vault
    function depositETH() public payable whenNotPaused nonReentrant withinBankCap(msg.value, address(0)) {
        vault[msg.sender][address(0)] += msg.value;
        totalTokenDeposits[address(0)] += msg.value;
        emit Deposited(msg.sender, address(0), msg.value);
    }

    /// @notice Deposit ERC-20 token into the vault
    /// @param token Address of the ERC-20 token
    /// @param amount Amount to deposit
    function depositToken(address token, uint256 amount) external whenNotPaused nonReentrant withinBankCap(amount, token) {
        if (token == address(0)) revert InvalidToken();
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        vault[msg.sender][token] += amount;
        totalTokenDeposits[token] += amount;
        emit Deposited(msg.sender, token, amount);
    }

    /// @notice Withdraw ETH from the vault
    /// @param amount Amount to withdraw
    function withdrawETH(uint256 amount) external whenNotPaused nonReentrant withinWithdrawalLimit(amount, address(0)) {
        if (vault[msg.sender][address(0)] < amount) revert InsufficientBalance();

        vault[msg.sender][address(0)] -= amount;
        totalTokenDeposits[address(0)] -= amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Withdrawn(msg.sender, address(0), amount);
    }

    /// @notice Withdraw ERC-20 token from the vault
    /// @param token Address of the ERC-20 token
    /// @param amount Amount to withdraw
    function withdrawToken(address token, uint256 amount) external whenNotPaused nonReentrant withinWithdrawalLimit(amount, token) {
        if (token == address(0)) revert InvalidToken();
        if (vault[msg.sender][token] < amount) revert InsufficientBalance();

        vault[msg.sender][token] -= amount;
        totalTokenDeposits[token] -= amount;

        IERC20(token).safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, token, amount);
    }

    /// @notice Owner-only function to recover mistakenly sent tokens
    /// @param token Address of the token to recover
    /// @param to Recipient address
    /// @param amount Amount to recover
    function recoverToken(address token, address to, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            (bool success, ) = to.call{value: amount}("");
            if (!success) revert TransferFailed();
        } else {
            IERC20(token).safeTransfer(to, amount);
        }
    }

    /// @notice Owner-only function to pause the contract
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Owner-only function to unpause the contract
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Converts a token amount to USD using Chainlink or 1:1 for stablecoins
    /// @param token Token address (address(0) for ETH)
    /// @param amount Amount of token
    /// @return usdValue USD value scaled to 6 decimals
    function _convertToUsd(address token, uint256 amount) internal view returns (uint256 usdValue) {
        if (token == address(0)) {
            uint256 ethPrice = getLatestEthUsdPrice(); // 8 decimals
            usdValue = (amount * ethPrice) / 1e20; // ETH has 18 decimals, we want 6
        } else {
            uint8 decimals = IERC20Metadata(token).decimals();
            usdValue = (amount * 1e6) / (10 ** decimals); // Normalize to 6 decimals
        }
    }

    /// @notice Gets the latest ETH/USD price from Chainlink
    /// @return price Price in USD with 8 decimals
    function getLatestEthUsdPrice() public view returns (uint256 price) {
        (, int256 rawPrice, , , ) = ethUsdPriceFeed.latestRoundData();
        price = uint256(rawPrice);
    }

    /// @notice Calculates total USD value of all token deposits
    /// @return totalUsd Total USD value scaled to 6 decimals
    function _totalBankUsd() internal view returns (uint256 totalUsd) {
        totalUsd = _convertToUsd(address(0), totalTokenDeposits[address(0)]);
        // Extend here to include ERC-20 tokens if needed
    }

    /// @notice Ensures the deposit does not exceed the global USD cap
    /// @param amount Amount of token to deposit
    /// @param token Token address (address(0) for ETH)
    modifier withinBankCap(uint256 amount, address token) {
        uint256 usdValue = _convertToUsd(token, amount);
        uint256 currentTotal = _totalBankUsd();
        if (currentTotal + usdValue > bankCapUsd) revert BankCapExceeded();
        _;
    }

    /// @notice Ensures the withdrawal does not exceed the USD limit
    /// @param amount Amount of token to withdraw
    /// @param token Token address (address(0) for ETH)
    modifier withinWithdrawalLimit(uint256 amount, address token) {
        uint256 usdValue = _convertToUsd(token, amount);
        if (usdValue > withdrawalLimitUsd) revert WithdrawalLimitExceeded();
        _;
    }

    /// @notice Thrown when a deposit exceeds the global bank cap
    error BankCapExceeded();

    /// @notice Thrown when a withdrawal exceeds the allowed transaction limit
    error WithdrawalLimitExceeded();

    /// @notice Thrown when a user tries to withdraw more than their vault balance
    error InsufficientBalance();

    /// @notice Thrown when ETH or token transfer fails
    error TransferFailed();

    /// @notice Thrown when an invalid token address is used
    error InvalidToken();

    /// @notice Accepts direct ETH transfers and redirects to deposit logic
    receive() external payable {
        depositETH();
    }

    /// @notice Fallback to reject unexpected calls
    fallback() external payable {
        revert();
    }
}
