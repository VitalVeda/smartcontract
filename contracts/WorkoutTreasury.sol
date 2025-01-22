// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract WorkoutTreasury is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public vvfitToken; // VVFIT token contract interface

    event TokenWithdrawn(
        address indexed token,
        address indexed to,
        uint256 amount
    );
    event ETHReceived(address indexed from, uint256 amount);

    // Custom Errors
    error InvalidTokenAddress();
    error InvalidRecipient();
    error ZeroAmount();
    error InsufficientBalance(uint256 requested, uint256 available);
    error ETHTransferFailed();

    constructor(address _vvfitAddress) Ownable(msg.sender) {
        vvfitToken = IERC20(_vvfitAddress);
    }

    /// @notice Withdraw VVFIT token from the treasury
    /// @param to Recipient address
    /// @param amount Amount to withdraw
    function withdrawToken(
        address to,
        uint256 amount
    ) external onlyOwner whenNotPaused nonReentrant {
        if (to == address(0)) revert InvalidRecipient();
        if (amount == 0) revert ZeroAmount();

        vvfitToken.safeTransfer(to, amount);
        emit TokenWithdrawn(address(vvfitToken), to, amount);
    }

    /// @notice Recover mistakenly sent ERC20 tokens from the treasury
    /// @param token The ERC20 token address
    /// @param to Recipient address
    /// @param amount Amount to withdraw
    function recoverToken(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner whenNotPaused nonReentrant {
        if (token == address(0)) revert InvalidTokenAddress();
        if (to == address(0)) revert InvalidRecipient();
        if (amount == 0) revert ZeroAmount();

        IERC20(token).safeTransfer(to, amount);
        emit TokenWithdrawn(token, to, amount);
    }

    /// @notice Get token balance of treasury
    /// @param token The ERC20 token address
    function getTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    /// @notice Emergency pause withdrawals
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause withdrawals
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Support for receiving ETH
    receive() external payable {
        emit ETHReceived(msg.sender, msg.value);
    }

    /// @notice Withdraw ETH from treasury
    /// @param to Recipient address
    /// @param amount Amount to withdraw
    function withdrawETH(
        address payable to,
        uint256 amount
    ) external onlyOwner whenNotPaused nonReentrant {
        if (to == address(0)) revert InvalidRecipient();
        if (amount > address(this).balance)
            revert InsufficientBalance(amount, address(this).balance);

        (bool success, ) = to.call{value: amount}("");
        if (!success) revert ETHTransferFailed();
    }
}
