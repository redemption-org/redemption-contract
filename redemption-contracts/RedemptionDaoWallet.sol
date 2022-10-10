// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)
pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./IRedemptionDaoWallet.sol";

contract RedemptionDaoWallet is IRedemptionDaoWallet{
    address public daoContract;
    address public ownerAddress;
    mapping(address=>bool)public daos;

    constructor(address _daoContract,address _ownerAddress){
        daoContract = _daoContract;
        ownerAddress = _ownerAddress;
        daos[_daoContract] = true;
    }

    function withdraw(address tokenContract,address to,uint256 amount)external override returns(bool){
        require(daos[msg.sender],"The caller is not a dao contract");
        require(IERC20(tokenContract).transfer(to, amount),"Transaction error");
        return true;
    }

    function addDaoContract(address _daoContract)external override returns(bool) {
        require(msg.sender == daoContract,"The caller is not a dao contract");
        daos[_daoContract] = true;
        return true;
    }
}