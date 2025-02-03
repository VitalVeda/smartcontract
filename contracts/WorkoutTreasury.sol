// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract WorkoutTreasury is
    Ownable2StepUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    IERC20 public vvfitToken; // VVFIT token contract interface

    // Emitted when tokens are withdrawn from the contract
    event TokenWithdrawn(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    // Emitted when the contract receives native currency
    event NativeReceived(address indexed from, uint256 amount);

    // Thrown when the provided token address is invalid
    error InvalidTokenAddress();
    // Thrown when the recipient address is invalid (zero address)
    error InvalidRecipient();
    // Thrown when the amount provided is zero.
    error ZeroAmount();
    // Thrown when the requested amount exceeds the available balance
    error InsufficientBalance(uint256 requested, uint256 available);
    // Thrown when a native token transfer fails
    error NativeTransferFailed();

    /**
     * @dev Initializes the contract with the provided VVFIT token address
     * This function is called only once during the contract deployment or initialization process
     * It sets up the contract owner, pausable functionality, reentrancy guard,
     * and stores the VVFIT token address
     * @param _vvfitAddress The address of the VVFIT token contract
     */
    function initialize(address _vvfitAddress) public initializer {
        __Ownable_init(_msgSender());
        __Pausable_init();
        __ReentrancyGuard_init();
        vvfitToken = IERC20(_vvfitAddress);
    }

    /**
     * @dev Allows the owner to withdraw a specified amount of VVFIT tokens to a recipient
     * @param to The address to which the tokens are to be sent
     * @param amount The amount of tokens to withdraw
     */
    function withdrawToken(
        address to,
        uint256 amount
    ) external onlyOwner nonReentrant whenNotPaused {
        if (to == address(0)) revert InvalidRecipient();
        if (amount == 0) revert ZeroAmount();

        vvfitToken.safeTransfer(to, amount);
        emit TokenWithdrawn(address(vvfitToken), to, amount);
    }

    /**
     * @dev Allows the owner to recover a specified amount of any ERC20 token from the contract and send it to a recipient
     * @param token The address of the ERC20 token to recover
     * @param to The address to which the tokens are to be sent
     * @param amount The amount of tokens to recover
     */
    function recoverToken(
        address token,
        address to,
        uint256 amount
    ) external onlyOwner nonReentrant whenNotPaused {
        if (token == address(0)) revert InvalidTokenAddress();
        if (to == address(0)) revert InvalidRecipient();
        if (amount == 0) revert ZeroAmount();

        IERC20(token).safeTransfer(to, amount);
        emit TokenWithdrawn(token, to, amount);
    }

    /**
     * @dev Get token balance of treasury
     * @param token The address of the ERC20 token
     */
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
        emit NativeReceived(msg.sender, msg.value);
    }

    /**
     * @dev Withdraw native token from treasury
     * @param to Recipient address
     * @param amount Amount to withdraw
     */
    function withdrawNative(
        address payable to,
        uint256 amount
    ) external onlyOwner nonReentrant whenNotPaused {
        if (to == address(0)) revert InvalidRecipient();
        if (amount > address(this).balance)
            revert InsufficientBalance(amount, address(this).balance);

        (bool success, ) = to.call{value: amount}("");
        if (!success) revert NativeTransferFailed();
    }

    /**
     * @dev Authorizes the upgrade to a new implementation contract.
     * Only contract owner can authorize the upgrade.
     * @param newImplementation The address of the new implementation contract.
     * @notice This function is required to be called by the `upgradeTo` function in UUPS upgradeable contracts.
     */
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
