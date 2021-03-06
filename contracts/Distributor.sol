// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "./interfaces/IBEP20.sol";
import "./library/SafeMath.sol";
import "./library/SafeBEP20.sol";
import "./interfaces/IDino.sol";
import "./interfaces/IMapper.sol";
import "./interfaces/IWBNB.sol";

contract Distributor {
    using SafeMath for uint;
    using SafeBEP20 for IBEP20;

    address public wbnb = 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd;
    //0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c
    //0x55d398326f99059fF775485246999027B3197955 usdt 18

    IDino public dino;

    uint public blocksPerYear;

    uint public startBlock;
    uint public endBlock;
    uint public totalWeight;

    uint[6] public tokenPerBlock;
    uint[6] private totalAmountUntilBonus;
    uint[6] private blocksPassed;

    uint public receiverFee;

    poolInfo[] public rewardPools;

    struct userInfo {
        uint minusAmount;
        uint depositAmount;
    }

    struct poolInfo {
        address token;
        uint rewardRate;
        uint lastBlock;
        uint totalBalance;
        uint weight;
    }

    mapping (address => mapping (uint => userInfo)) public userInfos;

    event NewRewardPool(uint indexed idx, address rewardPool, uint weight);
    event NewWeight(uint indexed idx, uint weight);

    event Deposit(
        address indexed account,
        uint indexed idx,
        uint amount);

    event Withdrawal(
        address indexed account,
        uint indexed idx,
        uint amount);

    event ClaimReward(
        address indexed account,
        uint indexed idx,
        uint amount);

    constructor (
        address _dino,
        uint _startBlock,
        uint _blocksPerYear,
        uint totalDistributingAmount,
        uint _receiverFee
    ) {
        dino = IDino(_dino);
        blocksPerYear = _blocksPerYear;
        startBlock = _startBlock;
        endBlock = _startBlock*5*blocksPerYear;
        receiverFee = _receiverFee;

        tokenPerBlock = [
            totalDistributingAmount*0.25e18/blocksPerYear,
            totalDistributingAmount*0.225e18/blocksPerYear,
            totalDistributingAmount*0.2e18/blocksPerYear,
            totalDistributingAmount*0.175e18/blocksPerYear,
            totalDistributingAmount*0.15e18/blocksPerYear,
            0
        ];

        totalAmountUntilBonus[0] = 0;
        for(uint i = 1; i<6; i++) {
            totalAmountUntilBonus[i] = totalAmountUntilBonus[i - 1] + tokenPerBlock[i - 1] * blocksPerYear;
        }

        blocksPassed = [
            0,
            blocksPerYear,
            blocksPerYear*2,
            blocksPerYear*3,
            blocksPerYear*4,
            blocksPerYear*5
        ];
    }

    function setDino(address _dino) public {
        require(msg.sender == dino.admin(), "Dino: admin");
        dino = IDino(_dino);
    }

    function addRewardPool(address token, uint weight) public {
        require(msg.sender == dino.admin(), "Dino: admin");
        for (uint i = 0; i < rewardPools.length; i++) {
            update(i);
        }
        rewardPools.push(
            poolInfo(
                token,
                0,
                startBlock > block.number ? startBlock : block.number,
                0,
                weight
            )
        );
        totalWeight = totalWeight.add(weight);
        emit NewRewardPool(rewardPools.length - 1, token, weight);
    }

    function setWeight(uint idx, uint weight) public {
        require(msg.sender == dino.admin(), "Dino: admin");
        for (uint i = 0; i < rewardPools.length; i++) {
            update(i);
        }
        totalWeight = totalWeight
            .sub(rewardPools[idx].weight)
            .add(weight);
        rewardPools[idx].weight = weight;

        emit NewWeight(idx, weight);
    }

    function getTotalReward(uint blockNumber) internal view returns (uint) {
        uint period = blockNumber.sub(startBlock);
        uint periodIdx = period.div(blocksPerYear);
        if(periodIdx > 5) periodIdx = 5;

        return totalAmountUntilBonus[periodIdx]
            .add(
                period
                    .sub(blocksPassed[periodIdx])
                    .mul(tokenPerBlock[periodIdx]));
    }

    function rewardPerPeriod(uint lastBlock) public view returns (uint) {
        uint currentBlock = block.number < startBlock ? startBlock : block.number;

        return getTotalReward(currentBlock)
            .sub(getTotalReward(lastBlock));
    }

    function rewardAmount(uint idx, address account) public view returns (uint) {
        poolInfo memory pool = rewardPools[idx];
        userInfo memory user = userInfos[account][idx];

        uint rewardRate = pool.rewardRate;
        if (block.number > pool.lastBlock && pool.totalBalance != 0) {
            rewardRate = rewardRate.add(
                rewardPerPeriod(pool.lastBlock)
                    .mul(pool.weight)
                    .div(totalWeight)
                    .mul(1e18)
                    .div(pool.totalBalance));
        }
        return user.depositAmount
            .mul(rewardRate)
            .div(1e18)
            .sub(user.minusAmount);
    }

    function deposit(uint idx, uint amount) public payable {
        require(idx < rewardPools.length, "Dino: pool");

        userInfo storage user = userInfos[msg.sender][idx];
        poolInfo storage pool = rewardPools[idx];

        if (user.depositAmount > 0) {
            claim(idx);
        } else {
            update(idx);
        }

        pool.totalBalance = pool.totalBalance.add(amount);

        user.depositAmount = user.depositAmount.add(amount);
        user.minusAmount = user.depositAmount
            .mul(pool.rewardRate)
            .div(1e18);

        if(pool.token == wbnb) {
            require(amount == msg.value, "Dino: bnb amount");
            IWBNB(wbnb).deposit{value: amount}();
        } else {
            IBEP20(pool.token).safeTransferFrom(msg.sender, address(this), amount);
        }

        emit Deposit(msg.sender, idx, amount);
    }

    function withdraw(uint idx, uint amount) public {
        require(idx < rewardPools.length, "Dino: pool");

        userInfo storage user = userInfos[msg.sender][idx];
        poolInfo storage pool = rewardPools[idx];

        claim(idx);

        pool.totalBalance = pool.totalBalance.sub(amount);

        user.depositAmount = user.depositAmount.sub(amount);
        user.minusAmount = user.depositAmount
            .mul(pool.rewardRate)
            .div(1e18);

        if(pool.token == wbnb) {
            IWBNB(wbnb).withdraw(amount);
            payable(msg.sender).transfer(amount);
        } else {
            IBEP20(pool.token).safeTransfer(msg.sender, amount);
        }

        emit Withdrawal(msg.sender, idx, amount);
    }

    function update(uint idx) private {
        poolInfo storage pool = rewardPools[idx];

        if (block.number <= pool.lastBlock) {
            return;
        }

        uint currentBlock = block.number >= endBlock
            ? endBlock
            : block.number;

        if (pool.totalBalance == 0) {
            pool.lastBlock = currentBlock;
            return;
        }

        uint rewardPerPool = rewardPerPeriod(pool.lastBlock)
            .mul(pool.weight)
            .div(totalWeight);

        pool.rewardRate = pool.rewardRate
            .add(rewardPerPool
                .mul(1e18)
                .div(pool.totalBalance));

        pool.lastBlock = currentBlock;
    }

    function claim(uint idx) public {
        require(idx < rewardPools.length, "Dino: pool");
        userInfo storage user = userInfos[msg.sender][idx];

        update(idx);

        uint reward = user.depositAmount
            .mul(rewardPools[idx].rewardRate)
            .div(1e18)
            .sub(user.minusAmount);

        if(reward > 0) {
            uint rewardToUser = reward.mul(uint(100).sub(receiverFee)).div(100);
            user.minusAmount = reward.add(user.minusAmount);
            dino.mint(msg.sender, rewardToUser);
            dino.mint(dino.receiver(), reward.sub(rewardToUser));
        }

        emit ClaimReward(msg.sender, idx, reward);
    }

    function getAllPoolLists() public view returns (address[] memory, uint[] memory, uint[] memory){
        address[] memory tokens = new address[](rewardPools.length);
        uint[] memory totalBalances = new uint[](rewardPools.length);
        uint[] memory weights = new uint[](rewardPools.length);
        for(uint i = 0; i < rewardPools.length; i++) {
            poolInfo memory pool = rewardPools[i];
            tokens[i] = pool.token;
            totalBalances[i] = pool.totalBalance;
            weights[i] = pool.weight;
        }
        return (tokens, totalBalances, weights);
    }

    receive() external payable {
        assert(msg.sender == wbnb);
    }
}