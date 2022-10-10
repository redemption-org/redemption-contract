// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

import "./Ownable.sol";
import "./IPriceFeeds.sol";
import "./IUniswapV2Pair.sol";

contract PriceFeeds is IPriceFeeds,Ownable{

    //1:usdt 2:bnb
    mapping(address=>uint256)public _types;
    address private _bnbUsdtLp = 0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE;
    
    function getTokenUsdtPrice(address _lp)external view returns(uint256){
        if(_types[_lp] == 1){
            return _getPairPrice(_lp);
        }else if(_types[_lp] == 2){
            uint256 tokenBnbPrice = _getPairPrice(_lp);
            uint256 bnbUsdtPrice = _getBnBPairPrice(_bnbUsdtLp);
            return (tokenBnbPrice * bnbUsdtPrice)/1e18;
        }
        return 0;
    }

    function getTokenBnbPrice(address _lp)external view returns(uint256){
        if(_types[_lp] == 2){
            return _getPairPrice(_lp);
        }else if(_types[_lp] == 1){
            uint256 tokenUsdtPrice = _getPairPrice(_lp);
            uint256 bnbUsdtPrice = _getBnBPairPrice(_bnbUsdtLp);
            return (tokenUsdtPrice*1e18)/bnbUsdtPrice;
        }
        return 0;
    }

    function setTokenLp(address _lp,uint256 _type)public onlyOwner returns(bool){
        _types[_lp] = _type;
        return true;
    }

    function _getPairPrice(address _tokenLp)public view returns(uint256){
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(_tokenLp).getReserves();
        return (reserve1*1e18)/reserve0;
    }

    function _getBnBPairPrice(address _tokenLp)public view returns(uint256){
        (uint256 reserve0, uint256 reserve1,) = IUniswapV2Pair(_tokenLp).getReserves();
        return (reserve0*1e18)/reserve1;
    }




}