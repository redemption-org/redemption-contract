// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)
pragma solidity ^0.8.0;

import "./Ownable.sol";
import "./IERC20.sol";


contract RedemptionNode is Ownable{

    uint256 public defaultDepositAmount = 1000 * 1e18;

    address public usdtContract;
    address public usdtRecipient;

    mapping(address=>bool)public nodes;


    constructor(address _usdtContract,address _usdtRecipient,uint256 _depositAmount){
        defaultDepositAmount = _depositAmount;
        usdtContract = _usdtContract;
        usdtRecipient = _usdtRecipient;
    }

    function isNode(address _user)public view returns(bool) {
        return nodes[_user];
    }

    function deposit()public returns(bool) {
        address _sender = msg.sender;
        require(!nodes[_sender],"has become a node");
        require(IERC20(usdtContract).transferFrom(_sender, address(this), defaultDepositAmount), "No approval or insufficient balance");
        require(IERC20(usdtContract).transfer(usdtRecipient, defaultDepositAmount),"PWDao:transfer failed");
        nodes[_sender] =true;
        return true;
    }

    function setRecipient(address _usdtRecipient) public virtual onlyOwner returns(bool){
        usdtRecipient = _usdtRecipient;
        return true;
    }


}