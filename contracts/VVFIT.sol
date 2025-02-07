// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
contract VVFIT is ERC20, Pausable, Ownable2Step, ERC20Burnable {
    using SafeERC20 for IERC20;
    // Divider which used in `calculatePercent` function
    uint256 public constant PERCENT_DIVIDER_DECIMALS = 100_000;

    // VVFIT has maximum total supply of 17,6 billion tokens
    uint256 public constant MAXIMUM_TOTAL_SUPPLY = 17600000000 * 1e18;

    /**
     * @dev Maximum percentage of the token's total supply allowed per transfer
     * In this case we can't use 100% because of solidity restrictions
     * We can use 100000 as representation of 100.
     * For example 30% is equal to the fraction 30/100,
     * We multiplied 100 by 1000 and multiply 30 by 1000 to keep the ratio
     * We end up with a fraction of 300/1000, which is equivalent to 30/100
     * If you want set max transfer percent to 30%, you need set max transfer percent variable to 30000
     * If you want set max transfer percent to 10%, you need set max transfer percent varible to 10000
     * This apply the same for percentage calculation in this contract
     */
    uint256 public maxTransferPercentage;

    // Shown Is max transfer amount functionality enabled;
    bool public maxTransferAmountEnabled = true;

    // blacklist[addressOfUser] = status
    mapping(address blacklistAddress => bool status) public blacklist;

    // whitelist[addressOfUser] = status
    mapping(address whitelistAddress => bool status) public whitelist;

    // Emitted when owner `enableMaxTransferAmount`
    event MaxTransferAmountEnabled(bool isEnabled);

    // Emitted when owner `updateBlacklist`
    event BlacklistUpdated(address indexed target, bool status);

    // Emitted when owner `updateBlacklist`
    event WhitelistUpdated(address indexed target, bool status);

    // Emitted when owner `setMaxTransferPercentage`
    event MaxTransferPercentageChanged(uint256 maxTransferPercentage);

    // Emitted when owner `withdrawToken`
    event WithdrawToken(
        address indexed user,
        address indexed token,
        uint256 amount
    );

    // Emitted when owner `withdrawNative`
    event WithdrawNative(address indexed user, uint256 amount);

    // Emitted when owner `mint`
    event Minted(
        address indexed minter,
        address indexed recipient,
        uint256 amount
    );

    // Emitted when contract receive native token
    event NativeReceived(address indexed from, uint256 amount);

    // Thrown when the recipient address is invalid (zero address)
    error InvalidRecipient();
    // Thrown when the requested amount exceeds the available balance
    error InsufficientBalance(uint256 requested, uint256 available);
    // Thrown when a native token transfer fails
    error NativeTransferFailed();
    // Thrown when the contract is paused, and the caller is not whitelisted
    error ContractPaused();
    // Thrown when the provided percentage exceeds the allowed range
    error InvalidPercentage();
    // Error thrown when the provided pool address is not a contract
    error InvalidLiquidityPool();
    // Error thrown when an address is blacklisted
    error BlacklistedAddress(address account);
    // Error thrown when the transfer amount is zero or negative
    error InvalidTransferAmount();
    // Error thrown when the transfer amount exceeds the maximum allowed
    error TransferAmountExceedsMax(uint256 provided, uint256 maxAllowed);
    // Error thrown when the minted amount exceeds the maximum caps
    error ExceedsMaximumSupply(uint256 requested, uint256 available);

    /**
     * @dev Initializes the contract with the provided parameters and sets the initial values
     * The constructor sets up the token name and symbol, as well as the maximum transfer percentage for each transfer
     * It also initializes the owner and whitelist
     * @param _name The name of the token
     * @param _symbol The symbol of the token
     * @param _maxTransferPercentage The percentage of the total supply that used to calculate maximum transfer amount each transaction
     *
     * @notice The contract deployer and the contract itself are automatically added to the whitelist
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxTransferPercentage
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        whitelist[_msgSender()] = true;
        whitelist[address(this)] = true;

        //Record amount of tokens which trigger autoLiquidity
        maxTransferPercentage = _maxTransferPercentage;
    }

    // Fallback function to accept native transfers
    receive() external payable {
        emit NativeReceived(msg.sender, msg.value);
    }

    // Modifier to ensure the contract is not paused, unless the addresses are whitelisted
    modifier checkContractPaused(address from, address to) {
        if (paused() && !whitelist[from] && !whitelist[to]) {
            revert ContractPaused();
        }
        _;
    }

    // Modifier to validate that a given percentage is within the allowed range
    modifier checkPercent(uint256 _percent) {
        if (_percent > PERCENT_DIVIDER_DECIMALS) {
            revert InvalidPercentage();
        }
        _;
    }

    /**
     * @dev Requirements:
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(
        address _to,
        uint256 _amount
    ) public override checkContractPaused(msg.sender, _to) returns (bool) {
        _checkWhitelistAndMaximumTransfer(_msgSender(), _to, _amount);

        return super.transfer(_to, _amount);
    }

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) public override checkContractPaused(_from, _to) returns (bool) {
        _checkWhitelistAndMaximumTransfer(_from, _to, _amount);

        return super.transferFrom(_from, _to, _amount);
    }

    /** @dev Pause contract and lock transfer
     */
    function pause() public onlyOwner {
        _pause();
    }

    /** @dev Unpause contract and unlock transfer
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @dev This function adds or remove an address to or from the blacklist
     * Only can be called by the Owner
     * @param _target Target address for blacklist
     * @param _status New status for address
     */
    function updateBlacklist(
        address _target,
        bool _status
    ) external onlyOwner returns (bool) {
        blacklist[_target] = _status;

        emit BlacklistUpdated(_target, _status);
        return true;
    }

    /**
     * @dev This function adds or remove an address to or from the whitelist
     * Only can be called by the Owner
     * @param _target Address which status changing
     * @param _status New status for address
     */
    function updateWhitelist(
        address _target,
        bool _status
    ) external onlyOwner returns (bool) {
        whitelist[_target] = _status;

        emit WhitelistUpdated(_target, _status);
        return true;
    }

    /**
     * @dev This function control max amount of token available for transfer functionality
     * Only can be called by the Owner
     * @param _isEnabled bool which shown: is max transfer amount enabled
     */
    function enableMaxTransferAmount(bool _isEnabled) external onlyOwner {
        maxTransferAmountEnabled = _isEnabled;

        emit MaxTransferAmountEnabled(_isEnabled);
    }

    /**
     * @dev This function sets new value for maxTransferPercentage
     * Only can be called by the Owner
     * @param _value New value for maxTransferPercentage
     */
    function setMaxTransferPercentage(
        uint256 _value
    ) external onlyOwner checkPercent(_value) {
        maxTransferPercentage = _value;

        emit MaxTransferPercentageChanged(_value);
    }

    /**
     * @dev Mint an amount of VVFIT token by an owner.
     * This method only called by contract owner.
     * @param amount amount of VVFIT token to be minted.
     * @param recipient minted token recipient address.
     */
    function mint(address recipient, uint256 amount) external onlyOwner {
        if (totalSupply() + amount > MAXIMUM_TOTAL_SUPPLY) {
            revert ExceedsMaximumSupply(
                amount,
                MAXIMUM_TOTAL_SUPPLY - totalSupply()
            );
        }
        _mint(recipient, amount);

        emit Minted(msg.sender, recipient, amount);
    }

    /** @dev Withdraw amount of chosen tokens from contract.
     * @param _token Amount of tokens for withdraw.
     * @param _receiver Address of tokens receiver.
     * @param _amount Amount of tokens for withdraw.
     */
    function withdrawToken(
        address _token,
        address _receiver,
        uint256 _amount
    ) external onlyOwner {
        if (_receiver == address(0)) {
            revert InvalidRecipient();
        }

        IERC20(_token).safeTransfer(_receiver, _amount);

        emit WithdrawToken(_receiver, _token, _amount);
    }

    /** @dev Withdraw amount of native token from contract
     * @param _receiver Address of receiver
     * @param _amount Amount for withdraw
     */
    function withdrawNative(
        address _receiver,
        uint256 _amount
    ) external onlyOwner {
        if (_receiver == address(0)) revert InvalidRecipient();
        if (_amount > address(this).balance)
            revert InsufficientBalance(_amount, address(this).balance);

        (bool success, ) = _receiver.call{value: _amount}("");
        if (!success) revert NativeTransferFailed();
    }

    /**
     * @dev Validates if the addresses are not blacklisted, checks transfer conditions before transferring the amount
     * This function ensures that the transfer amount is greater than zero, and if the transfer is not from a whitelisted address
     * It also ensures the transfer doesn't exceed the max allowed transfer amount
     * @param _from The address sending the tokens
     * @param _to The address receiving the tokens
     * @param _amount The amount of tokens to transfer
     */
    function _checkWhitelistAndMaximumTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) private view {
        if ((blacklist[_from] || blacklist[_to]) && _from != owner()) {
            revert BlacklistedAddress(_from);
        }

        if (_amount == 0) {
            revert InvalidTransferAmount();
        }

        uint256 transferThreshold = _calculatePercent(
            maxTransferPercentage,
            totalSupply()
        );

        if (!whitelist[_from] && !whitelist[_to]) {
            if (maxTransferAmountEnabled) {
                if (_amount > transferThreshold) {
                    revert TransferAmountExceedsMax(_amount, transferThreshold);
                }
            }
        }
    }

    // Calculate percentage
    function _calculatePercent(
        uint256 _percent,
        uint256 _price
    ) private pure returns (uint256) {
        return ((_percent * _price) / PERCENT_DIVIDER_DECIMALS);
    }

    // Check if provided address is a contract or not
    function _isContract(address _addr) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
}
