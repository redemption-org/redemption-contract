// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

import "./Ownable.sol";
import "./Oracle.sol";
import "./IERC20.sol";
import "./IERC721.sol";
import "./IPWSocialCard.sol";
import "./EnumerableSet.sol";
import "./Counters.sol";
import "./IRedemptionDaoWallet.sol";
import "./IPriceFeeds.sol";

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

contract RedemptionDao is Ownable,Oracle{

    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Counters for Counters.Counter;

    // mapping(address=>uint256)private energy;
    mapping(address=>uint256)private ztRewards;
    mapping(address=>uint256)private tdRewards;
    mapping(address=>uint256)private jbRewards;

    uint256 private jtTotalDepositAmount;
    uint256 private jtTotalWithdrawAmount;
    uint256 private dtTotalRewardAmount;
    uint256 private dtTotalWithdrawAmount;

    mapping(address=>uint256)private currentInvestmentAmount;
    mapping(address=>uint256)private lastInvestmentAmount;
    mapping(address=>uint256)private lastReardBlock;
    mapping(address=>bool)private activetas;

    mapping(address=>address) private _inviter;
    mapping(address=>uint256) private _level;
    mapping(address=>uint256) public cashFlows;
    mapping(address=>uint256) public ztCount;

    Counters.Counter private _orderIdCounter;
    mapping(uint256=>BuyOrder) public buyOrders;
    mapping(uint256=>SellOrder) public sellOrders;

    mapping(address => EnumerableSet.UintSet) private _buyOrderIds;
    mapping(address => EnumerableSet.UintSet) private _sellOrderIds;

    mapping(address=>address) public wallets;
    // mapping(address => EnumerableSet.AddressSet) private _parents;

    address public tokenContract;
    address public tokenTreasury;   //gasfee
    address public jtRewardTreasury;//静态奖励
    address public dtRewardTreasury;//动态奖励

    address public tenReardAddress;
    address public fiveReardAddress;
    address public devTokenAddress;
    address public treasuryAddress;

    address public tokenLpContract;
    address public priceFeedsContract;

    address public usdtContract;
    uint256 public min = 100 * 1e18;
    uint256 public max = 10000 * 1e18;

    uint256 private denominator = 10000;
    uint256 private gasFee = 100;

    uint256 private tjFee1 = 500;
    uint256 private tjFee2 = 200;
    uint256 private tjFee35 = 100;
    uint256 private tjFee6 = 200;
    uint256 private tjFee720 = 10;

    uint256 private l1Fee = 50;
    uint256 private l2Fee = 100;
    uint256 private l3Fee = 150;
    uint256 private l4Fee = 400;

    uint256 private tenFee = 800;
    uint256 private fiveFee = 500;
    uint256 private devFee = 200;

    uint256 public sReward3 = 500;
    uint256 public sReward7 = 1500;
    uint256 public sReward15 = 3500;

    address public dead = 0x000000000000000000000000000000000000dEaD;

    event Activate(uint256 indexed topc,address _user,address inviter);
    event BuyOrderEvent(uint256 indexed topc,uint256 _orderId,address _from, address _to ,uint256 _amount,uint256 _days);
    event SellOrderEvent(uint256 indexed topc,uint256 _orderId,address _from, address _to ,uint256 _amount);

    struct BuyOrder{
          uint256 _id;
          uint256 _days;
          uint256 _start_block_number;
          uint256 _end_block_number;
          uint256 _order_amount;
          address _from;
          address _to;
          uint256 _status;
          uint256 _timestamp;
    }

    struct SellOrder{
          uint256  _id;
          uint256 _block_number;
          uint256 _order_amount;
          address _from;
          address _to;
          uint256 _status; //0:提交， 1: 已匹配，2:已交易
          uint256 _timestamp;
    }

    constructor(address _tokenContract,address _usdtContract,address _tokenLpContract,address _priceFeedsContract){
        tokenContract = _tokenContract;
        usdtContract = _usdtContract;
        _inviter[dead] = owner();
        tokenLpContract = _tokenLpContract;
        priceFeedsContract = _priceFeedsContract;
        
        tokenTreasury = _createWallet(address(this));
        jtRewardTreasury = _createWallet(address(this));
        dtRewardTreasury = _createWallet(address(this));
    }

    function getInviter(address _sender)public view returns(address){
        return _inviter[_sender];
    }

    function ztReward()public payable payableOwner returns(bool){
        address _user = msg.sender;
        uint256 _maxRewardAmount = getMaxRewardAmount(_user);
        uint256 _realReawrdAmount = ztRewards[_user];
        if(ztRewards[_user] > _maxRewardAmount ){
            _realReawrdAmount = _maxRewardAmount;
        }
        _withdrawUsdt(dtRewardTreasury,_user,_realReawrdAmount);
        ztRewards[_user] -= _realReawrdAmount;
        dtTotalWithdrawAmount += _realReawrdAmount;
        return true;
    }

    function tdReward()public payable payableOwner returns(bool){
        address _user = msg.sender;
        uint256 _maxRewardAmount = getMaxRewardAmount(_user);
        uint256 _realReawrdAmount = tdRewards[_user];
        if(tdRewards[_user] > _maxRewardAmount ){
            _realReawrdAmount = _maxRewardAmount;
        }

        _withdrawUsdt(dtRewardTreasury,_user,_realReawrdAmount);
        tdRewards[_user] -= _realReawrdAmount;
        dtTotalWithdrawAmount += _realReawrdAmount;
        return true;
    }

    function jbReward()public payable payableOwner returns(bool){
        address _user = msg.sender;
        uint256 _maxRewardAmount = getMaxRewardAmount(_user);
        uint256 _realReawrdAmount = jbRewards[_user];
        if(jbRewards[_user] > _maxRewardAmount ){
            _realReawrdAmount = _maxRewardAmount;
        }

        _withdrawUsdt(dtRewardTreasury,_user,_realReawrdAmount);
        jbRewards[_user] -= _realReawrdAmount;
        dtTotalWithdrawAmount += _realReawrdAmount;
        return true;
    }
    
    function sync(address[] memory _userArray,address[] memory _inviterArray)public virtual onlyOwner returns(bool){
        for (uint i = 0; i < _userArray.length; i++) {
             _activate(_userArray[i],_inviterArray[i]);
        }
        return true;
    }
    
    function converge(uint256 _type, address[] memory _userArray)public virtual onlyOwner returns(bool){
        for (uint i = 0; i < _userArray.length; i++) {
            address _userWallt =  wallets[_userArray[i]];
            uint256 _walletBalance = IERC20(usdtContract).balanceOf(_userWallt);
            if(_userWallt != address(0) && _walletBalance >0){
                if(_type == 1){
                    _withdrawUsdt(_userWallt,jtRewardTreasury,_walletBalance);
                }else if(_type == 2){
                    _withdrawUsdt(_userWallt,dtRewardTreasury,_walletBalance);
                }
            }
        }

        return true;
    }

    function singleSettlement(address _user)public virtual onlyOwner returns(bool){
        uint256[] memory ids = _sellOrderIds[_user].values();
        settlement(ids);
        return true;
    }

    function settlement(uint256[] memory _orderIdArray)public virtual onlyOracle returns(bool){
        for (uint i = 0; i < _orderIdArray.length; i++) {
            SellOrder memory _sellOrder = sellOrders[_orderIdArray[i]];
            if(_sellOrder._status == 0){
                sellOrders[_orderIdArray[i]]._from = jtRewardTreasury;
                sellOrders[_orderIdArray[i]]._status = 1;
            }
        }
        return true;
    }

    function claim()public payable payableOwner returns(bool){
        address _user = msg.sender;
        uint256 _unclaimedAmount = 0; 
        uint256[] memory ids = _sellOrderIds[_user].values();
        for (uint i = 0; i < ids.length; i++) {
            SellOrder memory _sellOrder = sellOrders[ids[i]];
            if(_sellOrder._status == 1 && _sellOrder._from != address(0)){
                _unclaimedAmount += _sellOrder._order_amount;
                _withdrawUsdt(_sellOrder._from,_user,_sellOrder._order_amount);
                sellOrders[ids[i]]._status = 2;
                _sellOrderIds[_user].remove(ids[i]);
            }
        }
        jtTotalWithdrawAmount += _unclaimedAmount;
        return true;
    }

    function buy(uint256 _amount,uint256 _days)public payable payableOwner returns(uint256){
        address _sender = msg.sender;
        require(_sender != address(0), "Transfer from the zero address");
        require(_amount >= min && _amount <= max, "Beyond the range of purchases");
        address _userWallet = wallets[_sender];
        require(_userWallet != address(0), "User wallet not is a 0");

        require(IERC20(usdtContract).transferFrom(_sender, _userWallet, _amount), "No approval or insufficient balance");
        // require(IERC20(usdtContract).transfer(_userWallet, _amount),"PWDao:transfer failed");
        
        uint256 gasFeeAmount = _calculationRatio(gasFee,_amount);
        uint256 gasFeeTokenAmount = (gasFeeAmount*1e18)/getTokenUsdtPrice();
        require(IERC20(tokenContract).transferFrom(_sender, tokenTreasury, gasFeeTokenAmount), "No approval or insufficient balance");

        jtTotalDepositAmount += _amount;
        currentInvestmentAmount[_sender] += _amount;
        lastInvestmentAmount[_sender] = _amount;
        uint256 buyOrderId =  _createBuyOrder(_sender,_days,_amount);

        _takeRewards(_sender,_amount);
        emit BuyOrderEvent(2,buyOrderId,_sender,address(this),_amount,_days);
        return buyOrderId;
    }

    function sell()public payable payableOwner returns(uint256){
        address _sender = msg.sender;
        require(_sender != address(0), "Transfer from the zero address");
        uint256 maxSellAmount = getMaxSellAmount(_sender);

        uint256 gasFeeAmount = _calculationRatio(gasFee,maxSellAmount);
        uint256 gasFeeTokenAmount = (gasFeeAmount*1e18)/getTokenUsdtPrice();
        require(IERC20(tokenContract).transferFrom(_sender, address(this), gasFeeTokenAmount), "No approval or insufficient balance");
        
        uint256 sellOrderId = _createSellOrder(_sender,maxSellAmount);
        emit SellOrderEvent(3,sellOrderId,_sender,address(this),maxSellAmount);
        refreshBuyOrders(_sender);
        return sellOrderId;
    }

    function _createBuyOrder(address _user,uint256 _days,uint256 _amount)internal returns(uint256){
        uint256 orderId = _orderIdCounter.current();
        _orderIdCounter.increment();
        buyOrders[orderId]._id = orderId;
        buyOrders[orderId]._days = _days;
        buyOrders[orderId]._start_block_number = block.number;
        buyOrders[orderId]._end_block_number = block.number+(_days*28800);
        // buyOrders[orderId]._end_block_number = block.number+(_days*10);

        buyOrders[orderId]._order_amount = _amount;
        buyOrders[orderId]._from = _user;
        buyOrders[orderId]._to = address(this);
        buyOrders[orderId]._status = 1;
        buyOrders[orderId]._timestamp = block.timestamp;
        _buyOrderIds[_user].add(orderId);
        return orderId;
    }

    function _createSellOrder(address _user,uint256 _amount)internal returns(uint256){
        uint256 orderId = _orderIdCounter.current();
        _orderIdCounter.increment();
        sellOrders[orderId]._id = orderId;
        sellOrders[orderId]._block_number = block.number;
        sellOrders[orderId]._order_amount = _amount;
        sellOrders[orderId]._from = address(0);
        sellOrders[orderId]._to = _user;
        sellOrders[orderId]._status = 0;
        sellOrders[orderId]._timestamp = block.timestamp;
        _sellOrderIds[_user].add(orderId);
        return orderId;
    }

    function getMaxSellAmount(address _user)public view returns(uint256) {
        uint256[] memory ids = _buyOrderIds[_user].values();
        uint256 _totalSellAmount = 0;
        for (uint i = 0; i < ids.length; i++) {
            BuyOrder memory _buyOrder = buyOrders[ids[i]];
            if(block.number > _buyOrder._end_block_number || activetas[_user]){
                if(_buyOrder._days == 3){
                    _totalSellAmount = _totalSellAmount+_buyOrder._order_amount+_calculationRatio(sReward3,_buyOrder._order_amount);
                }else if(_buyOrder._days == 7){
                    _totalSellAmount = _totalSellAmount+_buyOrder._order_amount+_calculationRatio(sReward7,_buyOrder._order_amount);
                }else if(_buyOrder._days == 15){
                    _totalSellAmount = _totalSellAmount+_buyOrder._order_amount+_calculationRatio(sReward15,_buyOrder._order_amount);
                }
            }
        }
        return _totalSellAmount;
    }

    function getNotExpiredOrderCount(address _user)public view returns(uint256) {
        uint256[] memory ids = _buyOrderIds[_user].values();
        uint256 _count = 0;
        for (uint i = 0; i < ids.length; i++) {
            BuyOrder memory _buyOrder = buyOrders[ids[i]];
            if(block.number < _buyOrder._end_block_number || activetas[_user]){
                _count +=1;
            }
        }
        return _count;
    }

    function refreshBuyOrders(address _user)internal returns(bool) {
        uint256[] memory ids = _buyOrderIds[_user].values();
        uint256 _totalSellAmount = currentInvestmentAmount[_user];
        for (uint i = 0; i < ids.length; i++) {
            BuyOrder memory _buyOrder = buyOrders[ids[i]];
            if(block.number > _buyOrder._end_block_number || activetas[_user]){
                _buyOrderIds[_user].remove(ids[i]);
                _totalSellAmount  -= _buyOrder._order_amount;
            }
        }
        currentInvestmentAmount[_user] = _totalSellAmount;
        return true;
    }

    function getMaxRewardAmount(address _user)public view returns(uint256) {
        if(lastInvestmentAmount[_user]*5 > 5000 * 1e18){
            return 5000 * 1e18;
        }else {
            return lastInvestmentAmount[_user]*5;
        }
    }

    function getBuyMin(address _user)public view returns(uint256){
        if(lastInvestmentAmount[_user] >min && lastInvestmentAmount[_user] <=max){
            return lastInvestmentAmount[_user];
        }else if(lastInvestmentAmount[_user] >max){
            return max;
        }else {
             return min;
        }
    }

    function getBuyMax()public view returns(uint256) {
        return max;
    }

    // function getEnergyAmount(address _user)public view returns(uint256) {
    //     return energy[_user];
    // }

    function getDtTotalWithdrawAmount()public view returns(uint256) {
        return dtTotalWithdrawAmount;
    }

    function getDtTotalRewardAmount()public view returns(uint256) {
        return dtTotalRewardAmount;
    }

    function getJtTotalWithdrawAmount()public view returns(uint256) {
        return jtTotalWithdrawAmount;
    }

    function getJtTotalDepositAmount()public view returns(uint256) {
        return jtTotalDepositAmount;
    }

    function getZtRewardAmount(address _user)public view returns(uint256) {
        return ztRewards[_user];
    }

    function getTdRewardAmount(address _user)public view returns(uint256) {
        return tdRewards[_user];
    }

    function getJbRewardAmount(address _user)public view returns(uint256) {
        return jbRewards[_user];
    }

    function getUnclaimedAmount(address _user)public view returns(uint256) {
        uint256 _unclaimedAmount = 0; 
        uint256[] memory ids = _sellOrderIds[_user].values();
        for (uint i = 0; i < ids.length; i++) {
            SellOrder memory _sellOrder = sellOrders[ids[i]];
            if(_sellOrder._status == 1 && _sellOrder._from != address(0)){
                _unclaimedAmount += _sellOrder._order_amount;
            }
        }
        return _unclaimedAmount;
    }

    function getCurrentInvestmentAmount(address _user)public view returns(uint256) {
        return currentInvestmentAmount[_user];
    }

    function _takeRewards(address _user,uint256 _amount)internal {
        _takeZtReward(_user,_amount);
        tdRewards[tenReardAddress] += _calculationRatio(tenFee,_amount);
        tdRewards[devTokenAddress] += _calculationRatio(devFee,_amount);
        tdRewards[treasuryAddress] += _calculationRatio(devFee,_amount);

        dtTotalRewardAmount += _calculationRatio(tenFee+devFee+devFee,_amount);
    }

    //1 直推 2 团队 3 级别
    function _takeRewardItem(uint256 _type,address _user,uint256 _amount,uint256 _rate)internal {
        if(currentInvestmentAmount[_user] < _amount){
            _amount = currentInvestmentAmount[_user];
        }

        uint256 _rewardAmount = _calculationRatio(_rate,_amount);
        if(_type == 1){
            ztRewards[_user] += _rewardAmount;
            dtTotalRewardAmount += _rewardAmount;
        }else if(_type == 2){
            tdRewards[_user] += _rewardAmount;
            dtTotalRewardAmount += _rewardAmount;
        }
    }

        // 级别
    function _takeJbRewardItem(address _user,uint256 _reward_amount)internal {
        jbRewards[_user] += _reward_amount;
        dtTotalRewardAmount += _reward_amount;
    }

    function _takeZtReward(address _user,uint256 _amount)internal {
        address _inviterAddress = _user;
        //自己流水
        _addCashFlows(_user,_amount);

        bool l1 = false;
        bool l2 = false;
        bool l3 = false;
        bool l4 = false;

        uint256 _totalLevelReward = 0;

        for (uint i = 1; i <= 10; i++) {
           _inviterAddress = getInviter(_inviterAddress);
           if(_inviterAddress != address(0)){
                //团队流水
                _addCashFlows(_inviterAddress,_amount);

                //代数奖
               if(i==1){
                   if(ztCount[_inviterAddress]>=1){
                        _takeRewardItem(1,_inviterAddress,_amount,tjFee1);
                   }
                }else if(i==2){
                    if(ztCount[_inviterAddress] >= 2){
                        _takeRewardItem(2,_inviterAddress,_amount,tjFee2);
                    }
                }else if(i>=3 && i<=5){
                    if(ztCount[_inviterAddress] >= i){
                        _takeRewardItem(2,_inviterAddress,_amount,tjFee35);
                    }
                }else if(i == 6){
                    if(ztCount[_inviterAddress] >= 6){
                        _takeRewardItem(2,_inviterAddress,_amount,tjFee6);
                    }
                }else {
                    if(ztCount[_inviterAddress] >= i){
                        _takeRewardItem(2,_inviterAddress,_amount,tjFee720);
                    }
                }

                //级别奖
                uint256 _this_level = getLevel(_inviterAddress);
                if(_this_level == 1 && !l1){
                    uint256 _rewardAmount = _calculationRatio(l1Fee,_amount);
                    _takeJbRewardItem(_inviterAddress,_rewardAmount);
                    _totalLevelReward += _rewardAmount;
                    l1 = true;
                }else if(_this_level == 2 && !l2){
                   uint256 _rewardAmount = _calculationRatio(l2Fee,_amount);
                    _takeJbRewardItem(_inviterAddress,_rewardAmount);
                    _totalLevelReward += _rewardAmount; 
                    l2 = true;
                }else if(_this_level == 3 && !l3){
                    uint256 _rewardAmount = _calculationRatio(l3Fee,_amount);
                    _takeJbRewardItem(_inviterAddress,_rewardAmount);
                    _totalLevelReward += _rewardAmount; 
                    l3 = true;
                }else if(_this_level == 4 && !l4){
                    uint256 _rewardAmount = _calculationRatio(l4Fee,_amount);
                    if(_totalLevelReward < _rewardAmount){
                        _takeJbRewardItem(_inviterAddress,_rewardAmount-_totalLevelReward);
                    }
                    l4 = true;
                }
           }
        }
    }

    function _addCashFlows(address _user,uint256 _amount)internal {
       cashFlows[_user] += _amount;
        if(cashFlows[_user] >= 20000 * 1e18 && cashFlows[_user] < 60000 * 1e18){
            _addLevel(_user,1);
        }else if(cashFlows[_user] >= 60000 * 1e18 && cashFlows[_user] < 130000 * 1e18){
            _addLevel(_user,2);
        }else if(cashFlows[_user] >= 130000 * 1e18){
            _addLevel(_user,3);
        }
    }

    function _addLevel(address _user,uint256 _targetLevel)internal{
        if(_level[_user] < _targetLevel){
            _level[_user] = _targetLevel;
        }
    }

    function refreshTreasury()public onlyOwner returns(bool){
        jtRewardTreasury = _refreshTreasury(usdtContract,jtRewardTreasury);
        dtRewardTreasury = _refreshTreasury(usdtContract,dtRewardTreasury);
        return true;
    }

    function _refreshTreasury(address _tokenContract,address _lastTreasury)internal returns(address){
        uint256 tokenTreasuryBalance = IERC20(_tokenContract).balanceOf(_lastTreasury);
        if(tokenTreasuryBalance>0){
            address _cacheTokenTreasury = _createWallet(_lastTreasury);
            require(IRedemptionDaoWallet(_lastTreasury).withdraw(_tokenContract,_cacheTokenTreasury,tokenTreasuryBalance),"withdraw error");
            return _cacheTokenTreasury;
        }
        return _lastTreasury;
    }

    function _withdrawToken(address _wallet,address _to,uint256 _amount)internal {
        require(IRedemptionDaoWallet(_wallet).withdraw(tokenContract,_to,_amount),"withdraw error");
    }
    
    function _withdrawUsdt(address _wallet,address _to,uint256 _amount)internal {
        require(IRedemptionDaoWallet(_wallet).withdraw(usdtContract,_to,_amount),"withdraw error");
    }

    function _calculationRatio(uint256 ratio,uint256 total)internal view returns(uint256){
        return total*ratio/denominator;
    }

    //activate
    function activate(address _inviterAddress) public payable payableOwner returns (bool){
        address _user = msg.sender;
        require(_user!= _inviterAddress,"The invitee cannot be himself.");
        require(_inviter[_user] == address(0),"Already activated.");
        require(_inviter[_inviterAddress] != address(0),"The invitee is not activated.");

        _activate(_user,_inviterAddress);
        return true;
    }

    function _createWallet(address _user)internal returns(address) {
         RedemptionDaoWallet _wallet = new RedemptionDaoWallet(address(this),_user);
         address _walletAddress = address(_wallet);
         wallets[_user] = _walletAddress;
         return _walletAddress;
    }

    function _activate(address _user, address _inviterAddress)internal{
        _inviter[_user] = _inviterAddress;
        ztCount[_inviterAddress] += 1;
        _createWallet(_user);
        emit Activate(1,_user,_inviterAddress);
    }



    function getLevel(address _user)public view returns(uint256){
        return _level[_user];
    }

    function getCashFlow(address _user)public view returns(uint256){
        return cashFlows[_user];
    }

    /* ========== MODIFIERS ========== */

    modifier payableOwner() {
        if(msg.value >0){
            address payable _payableAddr = payable(owner());
            _payableAddr.transfer(msg.value);
        }
        _;
    }

    function _transferTokenTo(address to,uint256 amount)internal returns(bool){
        if(amount>0){
            return IERC20(tokenContract).transfer(to, amount);
        }
        return true;
    }

    function getTokenUsdtPrice() public view returns(uint256){
        if(priceFeedsContract == dead){
            return 1*1e18;
        }else{
            return IPriceFeeds(priceFeedsContract).getTokenUsdtPrice(tokenLpContract);
        }
    }

    function setParams(uint256 _cmd , uint256 _rate) public virtual onlyOwner returns(bool){
        if(_cmd == 1){
            min = _rate;
        }else if(_cmd == 2){
            max = _rate;
        }else if(_cmd == 3){
            gasFee = _rate;
        }else if(_cmd == 4){
            tjFee1 = _rate;
        }else if(_cmd == 5){
            tjFee2 = _rate;
        }else if(_cmd == 6){
            tjFee35 = _rate;
        }else if(_cmd == 7){
            tjFee6 = _rate;
        }else if(_cmd == 8){
            tjFee720 = _rate;
        }else if(_cmd == 9){
            l1Fee = _rate;
        }else if(_cmd == 10){
            l2Fee = _rate;
        }else if(_cmd == 11){
            l3Fee = _rate;
        }else if(_cmd == 12){
            l4Fee = _rate;
        }else if(_cmd == 13){
            tenFee = _rate;
        }else if(_cmd == 14){
            fiveFee = _rate;
        }else if(_cmd == 15){
            devFee = _rate;
        }else if(_cmd == 16){
            sReward3 = _rate;
        }else if(_cmd == 17){
            sReward7 = _rate;
        }else if(_cmd == 18){
            sReward15 = _rate;
        }

        return true;
    }

    function setContract(uint256 _index , address _contract) public virtual onlyOwner returns(bool){
        if(_index == 1){
            tokenContract = _contract;
        }else if(_index == 2){
           usdtContract = _contract;
        }else if(_index == 10){
            tokenTreasury = _contract;
        }else if(_index == 11){
            tenReardAddress = _contract;
        }else if(_index == 12){
            fiveReardAddress = _contract;
        }else if(_index == 13){
            devTokenAddress = _contract;
        }else if(_index == 14){
            treasuryAddress = _contract;
        }else if(_index == 15){
            priceFeedsContract = _contract;
        }else if(_index == 16){
            tokenLpContract = _contract;
        }
        return true;
    }

    function setLevel(address user,uint256 level) public virtual onlyOwner returns(bool){
        _level[user] = level;
        return true;
    }

    function setRewards(address _user,uint256 _amount) public virtual onlyOwner returns(bool){
        ztRewards[_user] = _amount;
        return true;
    }



}