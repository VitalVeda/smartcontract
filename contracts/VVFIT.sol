// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract VVFIT is ERC20, Pausable, Ownable2Step, ERC20Burnable {
    // Divider which used in `calculatePercent` function
    uint256 public constant PERCENT_DIVIDER_DECIMALS = 100_000;

    // VVFIT has maximum total supply of 176 million tokens
    uint256 public constant MAXIMUM_TOTAL_SUPPLY = 17600000000;

    /**
     * @dev Percent of tax calculation
     * Tax is a percentage of the price, but in this case we can't use 100% because of solidity restrictions
     * We can use 100000 as representation of 100.
     * For example 30% is equal to the fraction 30/100,
     * We multiplied 100 by 1000 and multiply 30 by 1000 to keep the ratio
     * We end up with a fraction of 300/1000, which is equivalent to 30/100
     * If you want set tax to 30%, you need set tax variable to 30000
     * If you want set tax to 10%, you need set tax varible to 10000
     * This apply the same for percentage calculation in this contract
     */
    uint256 public purchaseTaxPercent;

    // Percent of tax taken on token sales
    uint256 public salesTaxPercent;

    // Maximum percentage of the token's total supply allowed per transfer
    uint256 public maxTransferPercentage;

    // Shown Is max transfer amount functionality enabled;
    bool public maxTransferAmountEnabled = true;

    // blacklist[addressOfUser] = status
    mapping(address blacklistAddress => bool status) public blacklist;

    // whitelist[addressOfUser] = status
    mapping(address whitelistAddress => bool status) public whitelist;

    // list address of VVFIT pools on DEXs
    mapping(address poolAddress => bool isAdded) private _listPoolAddress;

    // Emitted when owner `enableMaxTransferAmount`
    event MaxTransferAmountEnabled(bool isEnabled);

    // Emitted when owner `updateBlacklist`
    event BlacklistUpdated(address indexed target, bool status);

    // Emitted when owner `updateBlacklist`
    event WhitelistUpdated(address indexed target, bool status);

    // Emitted when owner `setMaxTransferPercentage`
    event MaxTransferPercentageChanged(uint256 maxTransferPercentage);

    // Emitted when owner `setPercentageOfPurchaseTax`
    event PurchaseTaxChanged(uint256 purchaseTax);

    // Emitted when owner `setPercentageOfSalesTax`
    event SalesTaxChanged(uint256 salesTax);

    // Emitted when owner `addPoolAddress`
    event LiquidityPoolListAdded(address pool);

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

    /**
     * @dev Initializes the contract with the provided parameters and sets the initial values
     * The constructor sets up the token name and symbol, as well as the tax percentages for purchases and sales
     * It also records the maximum transfer percentage that triggers automatic liquidity, and initializes the owner and whitelist
     * @param _name The name of the token
     * @param _symbol The symbol of the token
     * @param _purchaseTaxPercent The tax percentage applied during token purchases
     * @param _salesTaxPercent The tax percentage applied during token sales
     * @param _maxTransferPercentage The percentage of the total supply that triggers automatic liquidity
     *
     * @notice The contract deployer and the contract itself are automatically added to the whitelist
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _purchaseTaxPercent,
        uint256 _salesTaxPercent,
        uint256 _maxTransferPercentage
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
        whitelist[_msgSender()] = true;
        whitelist[address(this)] = true;

        //Recording tax percent for sale
        salesTaxPercent = _salesTaxPercent;

        //Recording tax percent for purchase
        purchaseTaxPercent = _purchaseTaxPercent;

        //Record amount of tokens which trigger autoLiquidity
        maxTransferPercentage = _maxTransferPercentage;
    }

    // Fallback function to accept native transfers
    receive() external payable {
        emit NativeReceived(msg.sender, msg.value);
    }

    // Modifier to ensure the contract is not paused, unless the addresses are whitelisted
    modifier checkContractPaused(address from, address to) {
        require(
            !paused() || whitelist[from] || whitelist[to],
            "Pausable: Contract paused"
        );
        _;
    }

    // Modifier to validate that a given percentage is within the allowed range
    modifier checkPercent(uint256 _percent) {
        require(_percent <= PERCENT_DIVIDER_DECIMALS, "Invalid percentage");
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
        _checkWhitelistAndTransfer(_msgSender(), _to, _amount);

        return true;
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
        _checkWhitelistAndTransfer(_from, _to, _amount);

        address spender = _msgSender();
        _spendAllowance(_from, spender, _amount);

        return true;
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
     * @dev Sets new tax percent for transfer
     * @param _salesTaxPercent new percent of tax for sale.
     */
    function setPercentageOfSalesTax(
        uint256 _salesTaxPercent
    ) external onlyOwner checkPercent(_salesTaxPercent) {
        salesTaxPercent = _salesTaxPercent;

        emit SalesTaxChanged(_salesTaxPercent);
    }

    /**
     *  @dev Sets new tax percent for transfer
     * @param _purchaseTaxPercent new percent of purchase tax.
     */
    function setPercentageOfPurchaseTax(
        uint256 _purchaseTaxPercent
    ) external onlyOwner checkPercent(purchaseTaxPercent) {
        purchaseTaxPercent = _purchaseTaxPercent;

        emit PurchaseTaxChanged(purchaseTaxPercent);
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
     * @dev Add new address to pool list
     * Only can be called by the Owner
     * Trading happens inside the pool is charged a small amount of fee
     */
    function addPoolAddress(address _pool) external onlyOwner {
        require(_isContract(_pool), "Wrong liquidity pool");
        _listPoolAddress[_pool] = true;

        emit LiquidityPoolListAdded(_pool);
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
    ) external onlyOwner checkPercent(purchaseTaxPercent) {
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
        require(_receiver != address(0), "Invalid receiver address");

        IERC20(_token).transfer(_receiver, _amount);

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
     * @dev Validates if the addresses are not blacklisted, checks transfer conditions, and handles tax deduction before transferring the amount
     * This function ensures that the transfer amount is greater than zero, and if the transfer is not from a whitelisted address,
     * it calculates the applicable tax based on whether the transfer is a purchase or sale. It also ensures the transfer doesn't exceed the max allowed transfer amount
     * @param _from The address sending the tokens
     * @param _to The address receiving the tokens
     * @param _amount The amount of tokens to transfer
     */
    function _checkWhitelistAndTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) private {
        require(
            ((!blacklist[_from] && !blacklist[_to]) || _from == owner()),
            "Blacklisted address"
        );
        require(_amount > 0, "Transfer amount must be greater than zero");

        uint256 transferThreshold = _calculatePercent(
            maxTransferPercentage,
            totalSupply()
        );

        uint256 taxAmount;
        if (!whitelist[_from] && !whitelist[_to]) {
            if (maxTransferAmountEnabled) {
                require(
                    _amount <= transferThreshold,
                    "Transfer amount exceeds the maxTxAmount."
                );
            }

            if (_listPoolAddress[_to]) {
                taxAmount = _calculatePercent(salesTaxPercent, _amount);
            } else if (_listPoolAddress[_from]) {
                taxAmount = _calculatePercent(purchaseTaxPercent, _amount);
            }

            // Transfer tax amount
            if (taxAmount > 0) _transfer(_from, address(this), taxAmount);
        }

        uint256 restAmount = _amount - taxAmount;
        // Transfer the rest of amount to the recipient
        _transfer(_from, _to, restAmount);
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
