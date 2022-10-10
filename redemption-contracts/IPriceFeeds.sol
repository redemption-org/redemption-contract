// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;


interface IPriceFeeds {
    function getTokenUsdtPrice(address _lp)external view returns(uint256);
    function getTokenBnbPrice(address _lp)external view returns(uint256);
}