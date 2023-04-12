// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./NFT.sol";
import "./RWT.sol";
import "hardhat/console.sol";

contract Staking{

    using SafeMath for uint256;

    NFT public RFT;
    RWT public RWTS;
    IERC20 public STK;
    address public admin;
    uint256[] public tiers;
    uint256[] public rewardsPercentage;

    constructor(address _STK, address _RWT, address _RFT, uint256[] memory _tiers ,
    uint256[] memory _rewardsPercentage)
    {   
        RFT  = NFT(_RFT);
        RWTS = RWT(_RWT);
        STK  = IERC20(_STK);
        admin = msg.sender;
        rewardsPercentage = _rewardsPercentage;
        for (uint256 i = 0; i < _tiers.length; i++) {
            _tiers[i] *= 10**18;
        }
        tiers = _tiers;
    }
    //structs
    struct StakeInfo
    {
       bool isStaked;
       address staker;
       uint256 tierLevel;
       uint256 startTime;
       uint256 tokenStaked;
       uint256 lastTimeClaim;
       uint256 lastNFTclaimTime;
    }
    //mappings
    mapping(address => StakeInfo) public stakeinfo;

    // modifiers
    modifier onlyAdmin(){
        require(msg.sender == admin , "unautherized caller");
        _;
    }
    modifier validateStaker(){
        require(msg.sender ==  stakeinfo[msg.sender].staker , "invalid saker");
        _;
    }

    //admin events
    event TierAdded(uint256 indexed _tokensAmount , uint256 indexed _rewardsPercent ,uint256 indexed _addedAT);
    event TiersUpdated(uint256 indexed _tokensAmount ,  uint256 indexed _rewardsPercent, uint256 indexed _updateAt);
    //user events
    event claimNft(uint256 indexed _noOfNFTs , uint256 indexed _claimAT);
    event StakeTokens(uint256 indexed _tier , uint256 indexed _tokenStaked);
    event TierUpgraded(uint256 indexed _newStake , uint256 indexed _rewardTransfer);
    event RewardsClaim(uint256 indexed _rewardsTransfer , uint256 indexed _claimAT);
    event StakeWithdraw(uint256 indexed _stake , uint256 indexed _rewardsTransfer , uint256 indexed _withdrawerAt);
    
    // admin functions-------------------------------------------------------------------------------------------------|
    //  add new tier function (admin can add new staking tier with following function)
    function addNewTier(uint256 _tokenAmount  ,uint256 _rewardPecentage) public onlyAdmin  {

        require(_tokenAmount > 0 && _rewardPecentage > 0, "Either tokenAmount or Rewared percentage is zero");
        _tokenAmount*= 10**18;
   
        for(uint256 i=0; i < tiers.length; i++)
        {
            require(tiers[i] != _tokenAmount , "tokenAmount already present");
        }
        tiers.push(_tokenAmount);
        for(uint256 v=0; v < rewardsPercentage.length; v++)
        {
            require( rewardsPercentage[v] !=_rewardPecentage , "percentage aleady present");
        }
        rewardsPercentage.push(_rewardPecentage);
        emit TierAdded(_tokenAmount , _rewardPecentage , block.timestamp);
    }

    // delete tier function (admin can delete the staking tier with following function)
    function deleteTier(uint256 _tierIndex) public onlyAdmin{
        require(_tierIndex < tiers.length, "index out of bound");
        delete tiers[_tierIndex];
        delete rewardsPercentage[_tierIndex];   
    }
    // update existing tier functuion (admin can update the eixsting staking tier with following function)

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

        emit TiersUpdated(_tierAmount , _rewardPercent , block.timestamp);
    }     
    // read functions
    function getTiersInfo() public view returns(uint256[] memory _Tiersinfo){
        return tiers;
    }
    function getTiersCount() public view returns(uint256 _count){
        return tiers.length;
    }
    function getRewardsPercentage() public view returns(uint256[] memory _rewardsper){
        return rewardsPercentage;
    }
    function CheckPerDayReward(address _address) public view returns(uint256 _rewardperday){
        uint256 percentage = rewardsPercentage[stakeinfo[_address].tierLevel];
        return stakeinfo[msg.sender].tokenStaked.mul(percentage).div(10000);
    }
    function MyRewardsUnTillToday(address _address) public view returns(uint256 _rewardsUntillToday){
        uint256 timeElapsed = block.timestamp.sub(stakeinfo[_address].lastTimeClaim).div(60);
        return CheckPerDayReward(_address).mul(timeElapsed);
    }

    // user stake functions---------------------------------------------------------------------------------!

    // stake function
    function stake(uint256 _selectTier) public {

        require(_selectTier >= 0 && _selectTier < tiers.length , "invalid tier");
        require(STK.balanceOf(msg.sender) >= tiers[_selectTier] ,"insufficient balance");
        require(!stakeinfo[msg.sender].isStaked , "already staked");  
        
        stakeinfo[msg.sender]= StakeInfo({
            isStaked:true,
            staker:msg.sender,
            tierLevel:_selectTier,
            startTime:block.timestamp,
            tokenStaked: tiers[_selectTier],
            lastTimeClaim:block.timestamp, // this is the time when user last claim the tokens
            lastNFTclaimTime:block.timestamp // this is the time when user last claim the NFT
        });

        STK.transferFrom(msg.sender,address(this),tiers[_selectTier]);
        emit StakeTokens(_selectTier,tiers[_selectTier]);
    }
    // upgrade stake tier function
    function upGradeStakingTier(uint256 _desiredTier) public validateStaker {
        require(_desiredTier > stakeinfo[msg.sender].tierLevel  && _desiredTier < tiers.length, "invalid tier selected");
        // require(STK.balanceOf(msg.sender) >= tokensForUpdation ,"insufficient balance");// optional
        require(block.timestamp < stakeinfo[msg.sender].startTime.add(7 minutes) , "time passed,can not upgrade now");

        uint256 tokensForUpdation = tiers[_desiredTier].sub(stakeinfo[msg.sender].tokenStaked); 
        uint256 rewardsTransfer = MyRewardsUnTillToday(msg.sender);

        stakeinfo[msg.sender].tierLevel = _desiredTier;
        stakeinfo[msg.sender].tokenStaked = tiers[_desiredTier];
        stakeinfo[msg.sender].lastTimeClaim = block.timestamp;

        RWTS.mint(msg.sender,rewardsTransfer );  
        STK.transferFrom(msg.sender,address(this) ,tokensForUpdation); 
        emit TierUpgraded(tiers[_desiredTier],rewardsTransfer); 
    }
    // withdraw stake function
    function UnStake() public validateStaker{
        
        uint256 rewardsTransfer = MyRewardsUnTillToday(msg.sender);
        uint256 unStakeAmount = stakeinfo[msg.sender].tokenStaked;

        if(block.timestamp >= stakeinfo[msg.sender].startTime.add(7 minutes)){
            RWTS.mint(msg.sender,rewardsTransfer);  
            STK.transfer(msg.sender,stakeinfo[msg.sender].tokenStaked);
            delete stakeinfo[msg.sender];
        }else{
            STK.transfer(msg.sender,stakeinfo[msg.sender].tokenStaked);
            delete stakeinfo[msg.sender];
        }
        emit StakeWithdraw(unStakeAmount,rewardsTransfer , block.timestamp);
    }
    // claim rewards function
    function claimRewards() public validateStaker{
        require(block.timestamp >= stakeinfo[msg.sender].startTime.add(7 minutes) , "staking not completed");

        uint256 rewardsTransfer = MyRewardsUnTillToday(msg.sender);
        stakeinfo[msg.sender].lastTimeClaim = block.timestamp;
        
        RWTS.mint(msg.sender,rewardsTransfer);  
        emit RewardsClaim(rewardsTransfer , block.timestamp);
    }
    //claim NFT function
    function claimNFTs() public validateStaker{
        require(block.timestamp > stakeinfo[msg.sender].lastNFTclaimTime.add(30 minutes),"Time is not completed for claiming NFT");
        uint256 maxMintableNftnumber = stakeinfo[msg.sender].tierLevel.add(1);
        for(uint256 i=0; i < maxMintableNftnumber; i++){
            RFT.safeMint(msg.sender);
        }   
        stakeinfo[msg.sender].lastNFTclaimTime =  block.timestamp;
        emit claimNft(maxMintableNftnumber,block.timestamp);    
    }  
}