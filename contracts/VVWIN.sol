// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract VVWINToken is ERC20, AccessControl, Pausable {
    using SafeERC20 for IERC20;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant WHITELIST_ROLE = keccak256("WHITELIST_ROLE");
    uint256 public constant BASE_DENOMINATOR = 10_000;
    address public vvfitToken;
    uint256 public conversionRate;
    uint256 public conversionThreshold;

    // Custom errors
    error TransferNotAllowed(address sender, address recipient);
    error InvalidConversionRate(uint256 rate);
    error InvalidConversionThreshold(uint256 threshold);
    error InvalidWithdrawAmount(uint256 amount);
    error InvalidTokenAddress();

    // Events
    event Minted(address minter, address recipient, uint256 amount);
    event TokensConverted(
        address indexed user,
        uint256 amount,
        uint256 convertedAmount
    );
    event EmergencyWithdraw(
        address indexed admin,
        address indexed recipient,
        uint256 amount
    );
    event TokenWithdrawn(
        address indexed token,
        address indexed to,
        uint256 amount
    );

    constructor(
        string memory name,
        string memory symbol,
        address _vvfitToken,
        uint256 _conversionRate,
        uint256 _conversionThreshold
    ) ERC20(name, symbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        vvfitToken = _vvfitToken;
        conversionRate = _conversionRate;
        conversionThreshold = _conversionThreshold;
    }

    // Function to check if transfers are allowed (only whitelisted address are allowed to transfer)
    function isTransferAllowed() public view returns (bool) {
        if (hasRole(WHITELIST_ROLE, msg.sender) && !paused()) {
            return true;
        }

        return false;
    }

    // Mint function, only accessible by MINTER_ROLE
    function mint(
        address to,
        uint256 amount
    ) external whenNotPaused onlyRole(MINTER_ROLE) {
        _mint(to, amount);

        emit Minted(msg.sender, to, amount);
    }

    // Admin can pause/unpause transfers
    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    // Admin can set conversion rate
    function setConversionRate(
        uint256 _conversionRate
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_conversionRate == 0) {
            revert InvalidConversionRate(_conversionRate);
        }
        conversionRate = _conversionRate;
    }

    // Admin can set conversion threshold
    function setConversionThreshold(
        uint256 _conversionThreshold
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_conversionThreshold == 0) {
            revert InvalidConversionThreshold(_conversionThreshold);
        }
        conversionThreshold = _conversionThreshold;
    }

    // Auto conversion function
    function _autoConvert(address user) private {
        uint256 balance = balanceOf(user);
        if (balance >= conversionThreshold) {
            uint256 convertAmount = (balance * conversionRate) /
                BASE_DENOMINATOR;
            _burn(user, balance);

            IERC20(vvfitToken).safeTransfer(user, convertAmount);

            emit TokensConverted(user, balance, convertAmount);
        }
    }

    // Overide function
    function transfer(
        address to,
        uint256 value
    ) public override returns (bool) {
        if (!isTransferAllowed()) {
            revert TransferNotAllowed(msg.sender, to);
        }
        return super.transfer(to, value);
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override returns (bool) {
        if (!isTransferAllowed()) {
            revert TransferNotAllowed(from, to);
        }
        return super.transferFrom(from, to, value);
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override {
        super._update(from, to, value);
        _autoConvert(to);
    }

    // Emergency withdrawal function for admin
    function emergencyWithdrawVVFIT(
        address recipient,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) whenPaused {
        uint256 contractBalance = IERC20(vvfitToken).balanceOf(address(this));
        if (amount == 0 || amount > contractBalance) {
            revert InvalidWithdrawAmount(amount);
        }

        IERC20(vvfitToken).safeTransfer(recipient, amount);
        emit EmergencyWithdraw(msg.sender, recipient, amount);
    }

    // Allow admin to recover tokens in case tokens accidentally sent to this contract
    function recoverTokens(
        address token,
        address recipient,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(vvfitToken)) {
            revert InvalidTokenAddress();
        }
        IERC20(token).safeTransfer(recipient, amount);
        emit TokenWithdrawn(token, recipient, amount);
    }
}
