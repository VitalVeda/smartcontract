// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract VVFIT is ERC20, Pausable, Ownable, ERC20Burnable {
    //Divider which used in `calculatePercent` function
    uint256 public constant PERCENT_DIVIDER_DECIMALS = 100_000;

    //VVFIT has maximum total supply of 176 million tokens
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

    //Percent of tax taken on token sales
    uint256 public salesTaxPercent;

    // Maximum percentage of the token's total supply allowed per transfer
    uint256 public maxTransferPercentage;

    //Shown Is max transfer amount functionality enabled;
    bool public maxTransferAmountEnabled = true;

    //blacklist[addressOfUser] = status
    mapping(address => bool) public blacklist;

    //whitelist[addressOfUser] = status
    mapping(address => bool) public whitelist;

    //list address of VVFIT pools on DEXs
    mapping(address => bool) private _listPoolAddress;

    //Emitted when owner `enableMaxTransferAmount`
    event MaxTransferAmountEnabled(bool isEnabled);

    //Emitted when owner `updateBlacklist`
    event BlacklistUpdated(address target, bool status);

    //Emitted when owner `updateBlacklist`
    event WhitelistUpdated(address target, bool status);

    //Emitted when owner `setMaxTransferPercentage`
    event MaxTransferPercentageChanged(uint256 maxTransferPercentage);

    //Emitted when owner `setPercentageOfPurchaseTax`
    event PurchaseTaxChanged(uint256 purchaseTax);

    //Emitted when owner `setPercentageOfSalesTax`
    event SalesTaxChanged(uint256 salesTax);

    //Emitted when owner `addPoolAddress`
    event LiquidityPoolListAdded(address pool);

    //Emitted when owner `mint`
    event Minted(
        address indexed minter,
        address indexed recipient,
        uint256 amount
    );

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

    receive() external payable {}

    modifier checkContractPaused(address from, address to) {
        require(
            !paused() || whitelist[from] || whitelist[to],
            "Pausable: Contract paused"
        );
        _;
    }

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
        checkWhitelistAndTransfer(_msgSender(), _to, _amount);

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
        checkWhitelistAndTransfer(_from, _to, _amount);

        address spender = _msgSender();
        _spendAllowance(_from, spender, _amount);

        return true;
    }

    /** @notice Pause contract and lock transfer
     */
    function pause() public onlyOwner {
        _pause();
    }

    /** @notice Unpause contract and unlock transfer
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /** @notice Sets new tax percent for transfer
     * @param _salesTaxPercent new percent of tax for sale.
     */
    function setPercentageOfSalesTax(
        uint256 _salesTaxPercent
    ) external onlyOwner checkPercent(_salesTaxPercent) {
        salesTaxPercent = _salesTaxPercent;

        emit SalesTaxChanged(_salesTaxPercent);
    }

    /** @notice Sets new tax percent for transfer
     * @param _purchaseTaxPercent new percent of purchase tax.
     */
    function setPercentageOfPurchaseTax(
        uint256 _purchaseTaxPercent
    ) external onlyOwner checkPercent(purchaseTaxPercent) {
        purchaseTaxPercent = _purchaseTaxPercent;

        emit PurchaseTaxChanged(purchaseTaxPercent);
    }

    /**
     * @notice This function adds or remove an address to or from the blacklist
     * @dev Only can be called by the Owner
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
     * @notice This function adds or remove an address to or from the whitelist
     * @dev Only can be called by the Owner
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
        require(isContract(_pool), "Wrong liquidity pool");
        _listPoolAddress[_pool] = true;
    }

    /**
     * @notice This function control max amount of token available for transfer functionality
     * @dev Only can be called by the Owner
     * @param _isEnabled bool which shown: is max transfer amount enabled
     */
    function enableMaxTransferAmount(bool _isEnabled) external onlyOwner {
        maxTransferAmountEnabled = _isEnabled;

        emit MaxTransferAmountEnabled(_isEnabled);
    }

    /**
     * @notice This function sets new value for maxTransferPercentage
     * @dev Only can be called by the Owner
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

    /** @notice Withdraw amount of chosen tokens from contract.
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
    }

    /** @notice Withdraw amount of bnb from contract.
     * @param _receiver Address of receiver.
     * @param _amount Amount for withdraw.
     */
    function withdrawBNB(
        address _receiver,
        uint256 _amount
    ) external onlyOwner {
        require(_receiver != address(0), "Invalid receiver address");
        payable(_receiver).transfer(_amount);
    }

    function checkWhitelistAndTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) private {
        require(
            ((!blacklist[_from] && !blacklist[_to]) || _from == owner()),
            "Blacklisted address"
        );
        require(_amount > 0, "Transfer amount must be greater than zero");

        uint256 transferThreshold = calculatePercent(
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
                taxAmount = calculatePercent(salesTaxPercent, _amount);
            } else if (_listPoolAddress[_from]) {
                taxAmount = calculatePercent(purchaseTaxPercent, _amount);
            }

            // Transfer tax amount
            if (taxAmount > 0) _transfer(_from, address(this), taxAmount);
        }

        uint256 restAmount = _amount - taxAmount;
        // Transfer the rest of amount to the recipient
        _transfer(_from, _to, restAmount);
    }

    // Calculate percentage
    function calculatePercent(
        uint256 _percent,
        uint256 _price
    ) private pure returns (uint256) {
        return ((_percent * _price) / PERCENT_DIVIDER_DECIMALS);
    }

    // Check if provided address is a contract or not
    function isContract(address _addr) private view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }
}
