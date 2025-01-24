// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVVFIT is IERC20 {
    function PERCENT_DIVIDER_DECIMALS() external view returns (uint256);
    function MAXIMUM_TOTAL_SUPPLY() external view returns (uint256);

    function purchaseTaxPercent() external view returns (uint256);
    function salesTaxPercent() external view returns (uint256);
    function maxTransferPercentage() external view returns (uint256);
    function maxTransferAmountEnabled() external view returns (bool);

    function blacklist(address target) external view returns (bool);
    function whitelist(address target) external view returns (bool);

    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function pause() external;
    function unpause() external;

    function setPercentageOfSalesTax(uint256 _salesTaxPercent) external;
    function setPercentageOfPurchaseTax(uint256 _purchaseTaxPercent) external;

    function updateBlacklist(
        address _target,
        bool _status
    ) external returns (bool);
    function updateWhitelist(
        address _target,
        bool _status
    ) external returns (bool);
    function addPoolAddress(address _pool) external;

    function enableMaxTransferAmount(bool _isEnabled) external;
    function setMaxTransferPercentage(uint256 _value) external;

    function mint(address recipient, uint256 amount) external;

    function withdrawToken(
        address _token,
        address _receiver,
        uint256 _amount
    ) external;
    function withdrawBNB(address _receiver, uint256 _amount) external;
    function burn(uint256 value) external;
}
