// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./NFT.sol";
import "hardhat/console.sol";

contract Staking{

    using SafeMath for uint256;

    NFT public RFT;
    IERC20 public STK;
    IERC20 public RWT;
    
    address public admin;

    uint256[] public tiers;
    uint256[] public rewardsPercentage;

    constructor(address _STK, address _RWT, address _RFT, uint256[] memory _tiers ,
    uint256[] memory _rewardsPercentage)
    {   
        RFT = NFT(_RFT);
        STK = IERC20(_STK);
        RWT = IERC20(_RWT);
        admin = msg.sender;
        rewardsPercentage = _rewardsPercentage;

        for (uint256 i = 0; i < _tiers.length; i++) {
            _tiers[i] *= 10**18;
        }
        tiers = _tiers;
    
    }

    struct StakeInfo
    {
       bool isStaked;
       address staker;
       uint256 tierLevel;
       uint256 startTime;
       uint256 endTime;
       uint256 tokenStaked;
       uint256 rewardAmount;
    } mapping(address => StakeInfo) public mStakeInfo;

    
    mapping(address => bool ) mIsUpgraded;
    mapping(address => uint256) mStakersTier;
    mapping(address => bool) mIsClaimRewards;
    mapping(address => uint256) mLastTimeClaim;
    mapping(address => bool) mUnstakeBeforeTime;

    modifier onlyAdmin(){
        require(msg.sender == admin , "you are not the admin");
        _;
    }
    modifier validateStaker(){
        require(msg.sender ==  mStakeInfo[msg.sender].staker , "invalid saker");
        _;
    }
    modifier validateAddress(){
        require(msg.sender != address(0) , "invalid address");
        _;
    }

    event eAddTier(uint256 indexed _tokensAmount , uint256 indexed _rewardsPercent ,uint256 indexed _addedAT);
    event eUpdateTier(uint256 indexed _tokensAmount ,  uint256 indexed _rewardsPercent, uint256 indexed _updateAt);

    event eWithdrawStake(uint256 indexed _stake , uint256 _withdrawerAt);
    event eStakeTokens(uint256 indexed _tier , uint256 indexed _tokenStaked);
    event eUnstakeBeforeTime(uint256 indexed _stake , uint256 indexed _unStakeAt);
    event eClaimRewards(uint256 indexed _rewardAmount , uint256 indexed _claimeAt);    
    event eClaimExtraRewards(uint256 indexed _extraRewards , uint256 indexed _lastclaimAt);
    event eUpgradTier(uint256 indexed _prevStake , uint256 indexed _newStake , uint256 indexed _rewTransfer);
    event ewithdrawTokensAndClaimRewards(uint256 indexed _stake , uint256 indexed _reward , uint256 _withraAt);

    function getTiersInfo() public view onlyAdmin returns(uint256[] memory _Tiersinfo){
        return tiers;
    }
    function getTiersCount() public view onlyAdmin returns(uint256 _count){
        return tiers.length;
    }
    function getRewardsPercentage() public view onlyAdmin returns(uint256[] memory _rewardsper){
        return rewardsPercentage;
    }

    function addNewTier(uint256 _tokenAmount  ,uint256 _rewardPecentage) public onlyAdmin  {

        require(_tokenAmount > 0 && _rewardPecentage > 0, "Either tokenAmount or Rewared percentage is zero");
        _tokenAmount*= 10**18;
   
        for(uint256 i=0; i < tiers.length; i++){require(tiers[i] != _tokenAmount , "tokenAmount already present");}
        tiers.push(_tokenAmount);
        for(uint256 v=0; v < rewardsPercentage.length; v++)
        {require( rewardsPercentage[v] !=_rewardPecentage , "percentage aleady present");}

        rewardsPercentage.push(_rewardPecentage);

        emit eAddTier(_tokenAmount , _rewardPecentage , block.timestamp);
    }

    function updateExistingTier(uint256 _tierIndex , uint256 _tierAmount , uint256 _rewardIndex , uint256 _rewardPercent) public onlyAdmin{
        
        require(_tierIndex < tiers.length && _rewardIndex < rewardsPercentage.length , "index out of bound");
        require(_tierAmount !=0 && _rewardPercent !=0 , "tier amount can not be zero");
        require(_tierIndex == _rewardIndex , "indexex should be the same for upgrading");
        _tierAmount*= 10**18;
        for(uint256 i = 0; i < tiers.length; i++)
        {
            require(tiers[i] != _tierAmount , "tierAmount already present");
        }
        for(uint256 v = 0; v < rewardsPercentage.length; v++)
        {
            require(rewardsPercentage[v] != _rewardPercent , "percentage already present");
        }
        tiers[_tierIndex] = _tierAmount;
        rewardsPercentage[_rewardIndex] = _rewardPercent;

        emit eUpdateTier(_tierAmount , _rewardPercent , block.timestamp);
    }    

    // user functions

    function calculateReward(uint256 _tier , uint256 _tokenStaked) public view returns(uint256 _amount){
        uint256 reward;
        uint256 percent = rewardsPercentage[_tier];
        return reward = _tokenStaked.mul(percent).div(10000);
    }

    function stake(uint256 _selectTier) public validateAddress {

        require(_selectTier >= 0 && _selectTier < tiers.length , "invalid tier selected");
        require(STK.balanceOf(msg.sender) >= tiers[_selectTier] , "Do not have enough tokens");
        require(!mStakeInfo[msg.sender].isStaked , "you already staked the tokens");  
        
        mStakeInfo[msg.sender]= StakeInfo({
            isStaked:true,
            staker:msg.sender,
            tierLevel:_selectTier,
            startTime:block.timestamp,
            endTime:block.timestamp + 7 minutes,
            tokenStaked: tiers[_selectTier],
            rewardAmount:calculateReward(_selectTier , tiers[_selectTier])

        });

        mStakersTier[msg.sender] = _selectTier;

        STK.transferFrom(msg.sender,address(this),tiers[_selectTier]);
        emit eStakeTokens(_selectTier , tiers[_selectTier]);
    }

    function upGradeStakingTier(uint256 _desiredTier) public validateAddress validateStaker {
        require(_desiredTier > 0 && _desiredTier < tiers.length , "invalid tier selected");
        require(!mIsUpgraded[msg.sender], "you already upgraded your tier");
        require(mStakeInfo[msg.sender].isStaked = true , "did not found any stake");
        require(block.timestamp < mStakeInfo[msg.sender].endTime , "time completed , can not upgrade now");
        require(mStakeInfo[msg.sender].tierLevel != _desiredTier , "you already on this tier , select another");

        uint256 startTime = mStakeInfo[msg.sender].startTime;
        uint256 prevStake = mStakeInfo[msg.sender].tokenStaked;
        uint256 prvReward = mStakeInfo[msg.sender].rewardAmount;
        
        uint256 tRfU = tiers[_desiredTier].sub(prevStake);
        uint256 newStake = tRfU.add(prevStake);

        uint256 rewardsPerDay = prvReward.div(7);
        uint256 timeTillUpgrade =  block.timestamp.sub(startTime);
        uint256 timeElapsed = timeTillUpgrade.div(60);
        uint256 tillRewardSend = rewardsPerDay.mul(timeElapsed);

        mStakeInfo[msg.sender]= StakeInfo({
            isStaked:true,
            staker:msg.sender,
            tierLevel:_desiredTier,
            startTime:block.timestamp,
            endTime:block.timestamp + 7 minutes,
            tokenStaked: tiers[_desiredTier],
            rewardAmount:calculateReward(_desiredTier , tiers[_desiredTier])
        });
        mIsUpgraded[msg.sender] = true;
        RWT.transfer(msg.sender,tillRewardSend);  
        STK.transferFrom(msg.sender,address(this), tRfU);
        emit eUpdateTier(prevStake,newStake,tillRewardSend);
    }

    function  unStakeBeforeTime() public validateAddress validateStaker{      
        require(!mUnstakeBeforeTime[msg.sender],"tokens already unstaked before time");

        uint256 _tokens = mStakeInfo[msg.sender].tokenStaked;

        if(block.timestamp < mStakeInfo[msg.sender].endTime)
        {
            mUnstakeBeforeTime[msg.sender] = true;    
            delete mStakeInfo[msg.sender];
            STK.transfer(msg.sender,_tokens); 
            emit eUnstakeBeforeTime(_tokens , block.timestamp);
        }   
        else{
            revert("time is completed please claim your rewards");
        }
    }

    function ClaimRewards()  public validateAddress validateStaker {
        require(block.timestamp >= mStakeInfo[msg.sender].endTime , "staking not completed");
        require(!mIsClaimRewards[msg.sender] , "you already claim your rewards");

        uint256 rewardToSend = mStakeInfo[msg.sender].rewardAmount;
        uint256 tierlevel = mStakeInfo[msg.sender].tierLevel;
        uint256 endtime = mStakeInfo[msg.sender].endTime;
        
        mIsClaimRewards[msg.sender] = true;
        mLastTimeClaim[msg.sender] = block.timestamp;

           mCND[msg.sender] = claimNFTdetails({
            staker:msg.sender,
            tierlevel:tierlevel,
            stakingEndTime:endtime
        });

        RWT.transfer(msg.sender,rewardToSend); 
        emit eClaimRewards(rewardToSend , block.timestamp);
    }

    uint256 public myTillReward;

    function  claimExtraRewards() public validateAddress validateStaker {
        require(block.timestamp > mStakeInfo[msg.sender].endTime + 1 minutes , "Time not completed yet for extra claims");
        require(mStakeInfo[msg.sender].isStaked , "staking not found");
        require(mIsClaimRewards[msg.sender], "please claim your tier rewards first");

        uint256 lastTimeClaim = mLastTimeClaim[msg.sender];
        uint256 reward = mStakeInfo[msg.sender].rewardAmount;

        uint256 rewardsPerDay = reward.div(7);
        uint256 timeTillUpgrade =  block.timestamp.sub(lastTimeClaim);
        uint256 timeElapsed = timeTillUpgrade.div(60);
        uint256 tillRewardSend = rewardsPerDay.mul(timeElapsed);

        myTillReward = tillRewardSend;

        mLastTimeClaim[msg.sender] = block.timestamp;
        RWT.transfer(msg.sender , tillRewardSend);

        emit eClaimExtraRewards(tillRewardSend , block.timestamp);
    }

     function WithdrawStake() public validateAddress validateStaker {
        require(block.timestamp > mStakeInfo[msg.sender].endTime ,"staking in progress");

        if(mIsClaimRewards[msg.sender] = true )
        {
            uint256 stakes = mStakeInfo[msg.sender].tokenStaked;
            uint256 tierlevel = mStakeInfo[msg.sender].tierLevel;
            uint256 endtime = mStakeInfo[msg.sender].endTime;

            delete mStakeInfo[msg.sender];

            mIsUpgraded[msg.sender] = false;
            mIsClaimRewards[msg.sender]= false;
            mLastTimeClaim[msg.sender] = 0;

            mCND[msg.sender] = claimNFTdetails({
                staker:msg.sender,
                tierlevel:tierlevel,
                stakingEndTime:endtime
            });
            
            STK.transfer(msg.sender,stakes);
            emit eWithdrawStake(stakes , block.timestamp);
        }
        else{
            revert("please claim rewards before withdrawing stake");
        }
    }

    function withdrawTokensAndClaimRewards() public validateAddress validateStaker {

        require(block.timestamp >= mStakeInfo[msg.sender].endTime , "staking time not completed");
        
        uint256 tokens = mStakeInfo[msg.sender].tokenStaked;
        uint256 rewards = mStakeInfo[msg.sender].rewardAmount;
        uint256 tierlevel = mStakeInfo[msg.sender].tierLevel;
        uint256 endtime = mStakeInfo[msg.sender].endTime;

        

        delete mStakeInfo[msg.sender];

        mCND[msg.sender] = claimNFTdetails({
            staker:msg.sender,
            tierlevel:tierlevel,
            stakingEndTime:endtime
        });

        mIsUpgraded[msg.sender] = false;
        mIsClaimRewards[msg.sender]= false;
        mLastTimeClaim[msg.sender] = 0;

        RWT.transfer(msg.sender,rewards);
        STK.transfer(msg.sender,tokens);
        emit ewithdrawTokensAndClaimRewards(tokens,rewards,block.timestamp);
    }

    struct claimNFTdetails
    {
        address staker;
        uint256 tierlevel;
        uint256 stakingEndTime;
    }

    mapping(address=>claimNFTdetails) public mCND;

    function ClaimNFTrwards() public validateAddress {
        require(msg.sender == mCND[msg.sender].staker , "invalid staker");    
        require(block.timestamp > mCND[msg.sender].stakingEndTime + 5 minutes ,"Time is not completed for claiming NFT");
        
        uint256 maxMintableNftnumber = mCND[msg.sender].tierlevel + 1;

        for(uint256 i=0; i < maxMintableNftnumber; i++)
        {
            RFT.safeMint(msg.sender);
        }   
        delete mCND[msg.sender];
    }

}