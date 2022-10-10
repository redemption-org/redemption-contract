// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)
pragma solidity ^0.8.0;

import "./IERC20.sol";

interface IRedemptionDaoWallet{

    function withdraw(address tokenContract,address to,uint256 amount)external returns(bool);
    
    function addDaoContract(address _daoContract)external returns(bool);
}
