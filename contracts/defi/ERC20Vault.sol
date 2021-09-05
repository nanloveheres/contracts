//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../utils/AdminRole.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "hardhat/console.sol";

contract ERC20Vault is AdminRole {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public TOTAL_ALLOC_POINT = 10000; // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public TOTAL_SHARE = 1e30;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt or paid reward.
        uint256 rewardBalance;
        uint256 depositTime;
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 stakeToken; // Address of LP token contract.
        IERC20 rewardToken;
        uint256 allocPoint; // How many allocation points assigned to this pool. Rewards to distribute per second.
        uint256 lastRewardTime; // Last time that Rewards distribution occurs.
        uint256 accRewardTokenPerShare; // Accumulated Rewards per share, times 1e30 (10**30). See below.
        uint256 totalStaked; // Keep track of number of tokens staked in case the contract earns reflect fees
        uint256 startTime;
        uint256 endTime;
        uint256 userCount;
    }

    mapping(uint256 => mapping(address => UserInfo)) poolUsers; // Info of each user that stakes LP tokens.
    // Reward tokens created per second.
    uint256 public rewardUnit;
    // Info of each pool.
    PoolInfo[] public poolInfo;
    uint256 public poolCount = 0;

    event Deposit(uint256 indexed poolId, address indexed user, uint256 amount);
    event DepositRewards(uint256 indexed poolId, uint256 amount);
    event Withdraw(uint256 indexed poolId, address indexed user, uint256 amount);
    event EmergencyWithdraw(uint256 indexed poolId, address indexed user, uint256 amount);
    event EmergencyRewardWithdraw(uint256 indexed poolId, address indexed user, uint256 amount);
    event SkimStakeTokenFees(uint256 indexed poolId, address indexed user, uint256 amount);

    receive() external payable {}

    constructor() {}

    /// Deposit staking token into the contract to earn rewards.
    /// @dev Since this contract needs to be supplied with rewards we are
    ///  sending the balance of the contract if the pending rewards are higher
    /// @param _amount The amount of staking tokens to deposit
    function deposit(uint256 _pid, uint256 _amount) external payable {
        require(_pid < poolCount, "invalid pool id");
        require(_amount > 0, "invalid amount");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = poolUsers[_pid][msg.sender];
        _updatePoolRewardShare(_pid);
        uint256 pendingRewardBalance = _getPendingReward(user, pool.accRewardTokenPerShare);

        console.log("pendingRewardBalance: %s", pendingRewardBalance);

        bool isNew = (user.amount == 0);

        pool.stakeToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        pool.totalStaked += _amount;
        if (isNew) {
            pool.userCount += 1;
        }

        user.amount += _amount;
        user.rewardBalance = pendingRewardBalance;
        user.rewardDebt = user.amount.mul(pool.accRewardTokenPerShare).div(TOTAL_SHARE);
        // user.depositTime = block.timestamp;

        emit Deposit(_pid, msg.sender, _amount);
    }

    /// Withdraw rewards and/or staked tokens.
    /// @param _amount The amount of staking tokens to withdraw
    function withdraw(uint256 _pid, uint256 _amount) external payable {
        require(_pid < poolCount, "invalid pool id");
        require(_amount > 0, "invalid amount");
        uint256 userDepositAmount = getDepositAmount(_pid, msg.sender);
        require(userDepositAmount >= _amount, "insufficient user deposit");
        require(stakedBalance(_pid) >= _amount, "insufficient staked balance");

        _updatePoolRewardShare(_pid);

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = poolUsers[_pid][msg.sender];

        // uint256 userPendingReward = pendingReward(_pid, msg.sender);

        console.log("vault  : %s", pool.stakeToken.balanceOf(address(this)));
        console.log("_amount: %s", _amount);

        pool.stakeToken.safeTransfer(address(msg.sender), _amount);

        pool.totalStaked -= _amount;
        bool isRemoved = (userDepositAmount == _amount);
        if (isRemoved) {
            uint256 userPendingReward = _getPendingReward(user, pool.accRewardTokenPerShare);
            safeTransferReward(_pid, address(msg.sender), userPendingReward);
            pool.userCount -= 1;
            user.amount = 0;
            user.rewardBalance = 0;
        } else {
            user.amount -= _amount;
        }

        user.rewardDebt = user.amount.mul(pool.accRewardTokenPerShare).div(TOTAL_SHARE);
        // user.depositTime = block.timestamp;
        emit Withdraw(_pid, msg.sender, _amount);
    }

    // function harvest(uint256 _pid) public payable {
    //     UserInfo storage user = poolUsers[_pid][msg.sender];

    //     uint256 userPendingReward = pendingReward(_pid, msg.sender);
    //     safeTransferReward(_pid, address(msg.sender), user.rewardDebt + userPendingReward);
    //     user.rewardDebt += userPendingReward;
    //     user.rewardBalance = 0;
    //     user.depositTime = block.timestamp;
    // }

    // View function to see pending Reward on frontend.
    function pendingReward(uint256 _pid, address _user) public view returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = poolUsers[_pid][_user];
        if (user.amount == 0 || block.timestamp <= user.depositTime) {
            return 0;
        }

        uint256 accRewardTokenPerShare = pool.accRewardTokenPerShare;
        if (block.timestamp > pool.lastRewardTime && pool.totalStaked > 0) {
            uint256 multiplier = _getMultiplier(_pid, pool.lastRewardTime, block.timestamp);
            uint256 tokenReward = multiplier.mul(rewardUnit).mul(pool.allocPoint).div(TOTAL_ALLOC_POINT);
            accRewardTokenPerShare += tokenReward.mul(TOTAL_SHARE).div(pool.totalStaked);
        }

        return _getPendingReward(user, accRewardTokenPerShare);
    }

    function _getPendingReward(UserInfo memory user, uint256 _accRewardTokenPerShare) public view returns (uint256) {
        return user.amount.mul(_accRewardTokenPerShare).div(TOTAL_SHARE).add(user.rewardBalance).sub(user.rewardDebt);
    }

    // Return reward multiplier over the given _from to _to block.
    function _getMultiplier(
        uint256 _pid,
        uint256 _from,
        uint256 _to
    ) private view returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];
        if (_to <= pool.endTime) {
            return _to.sub(_from);
        } else if (_from >= pool.endTime) {
            return 0;
        } else {
            return pool.endTime.sub(_from);
        }
    }

    function _updatePoolRewardShare(uint256 _pid) private {
        require(_pid < poolCount, "invalid pool id");

        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }
        if (pool.totalStaked == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }

        uint256 multiplier = _getMultiplier(_pid, pool.lastRewardTime, block.timestamp);
        uint256 tokenReward = multiplier.mul(rewardUnit).mul(pool.allocPoint).div(TOTAL_ALLOC_POINT);
        pool.accRewardTokenPerShare += tokenReward.mul(TOTAL_SHARE).div(pool.totalStaked);
        pool.lastRewardTime = block.timestamp;
    }

    function getDepositAmount(uint256 _pid, address _user) public view returns (uint256) {
        return poolUsers[_pid][_user].amount;
    }

    function stakedBalance(uint256 _pid) public view returns (uint256) {
        return poolInfo[_pid].stakeToken.balanceOf(address(this));
    }

    function rewardBalance(uint256 _pid) public view returns (uint256) {
        return poolInfo[_pid].rewardToken.balanceOf(address(this));
    }

    // Deposit Rewards into contract
    function depositRewards(uint256 _pid, uint256 _amount) external payable{
        require(_amount > 0, "invalid amount");
        poolInfo[_pid].rewardToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        emit DepositRewards(_pid, _amount);
    }

    function safeTransferReward(
        uint256 _pid,
        address _to,
        uint256 _amount
    ) internal {
        poolInfo[_pid].rewardToken.safeTransfer(_to, _amount);
    }

    /* Admin Functions */
    function newPool(
        IERC20 _stakeToken,
        IERC20 _rewardToken,
        uint256 _allocPoint,
        uint256 _startTime,
        uint256 _endTime
    ) external payable onlyOwner {
        poolInfo.push(
            PoolInfo({
                stakeToken: _stakeToken,
                rewardToken: _rewardToken,
                allocPoint: _allocPoint,
                lastRewardTime: _startTime,
                accRewardTokenPerShare: 0,
                totalStaked: 0,
                startTime: _startTime,
                endTime: _endTime,
                userCount: 0
            })
        );

        poolCount += 1;
    }

    function updatePool(
        uint256 _pid,
        uint256 _allocPoint,
        uint256 _startTime,
        uint256 _endTime
    ) external payable onlyOwner {
        PoolInfo storage pool = poolInfo[_pid];

        pool.allocPoint = _allocPoint;
        pool.startTime = _startTime;
        pool.lastRewardTime = _startTime;
        pool.endTime = _endTime;
    }

    /// @param _rewardUnit The amount of reward tokens to be given per block
    function setRewardUnit(uint256 _rewardUnit) external onlyOwner {
        rewardUnit = _rewardUnit;
    }

    // /// @param  _bonusEndTime The block when rewards will end
    // function setBonusEndTime(uint256 _bonusEndTime) external onlyOwner {
    //     require(_bonusEndTime > bonusEndTime, "new bonus end block must be greater than current");
    //     bonusEndTime = _bonusEndTime;
    // }

    // /// @dev Obtain the stake token fees (if any) earned by reflect token
    // function getStakeTokenFeeBalance() public view returns (uint256) {
    //     return totalStakeTokenBalance().sub(totalStaked);
    // }

    // /// @dev Obtain the stake balance of this contract
    // /// @return wei balace of contract
    // function totalStakeTokenBalance() public view returns (uint256) {
    //     // Return BEO20 balance
    //     return stakeToken.balanceOf(address(this));
    // }

    // /// @dev Remove excess stake tokens earned by reflect fees
    // function skimStakeTokenFees() external onlyOwner {
    //     uint256 stakeTokenFeeBalance = getStakeTokenFeeBalance();
    //     stakeToken.safeTransfer(msg.sender, stakeTokenFeeBalance);
    //     emit SkimStakeTokenFees(msg.sender, stakeTokenFeeBalance);
    // }

    // /* Emergency Functions */

    // // Withdraw without caring about rewards. EMERGENCY ONLY.
    // function emergencyWithdraw() external {
    //     PoolInfo storage pool = poolInfo[0];
    //     UserInfo storage user = users[msg.sender];
    //     pool.stakeToken.safeTransfer(address(msg.sender), user.amount);
    //     totalStaked = totalStaked.sub(user.amount);
    //     user.amount = 0;
    //     user.rewardDebt = 0;
    //     emit EmergencyWithdraw(msg.sender, user.amount);
    // }

    // // Withdraw reward. EMERGENCY ONLY.
    // function emergencyRewardWithdraw(uint256 _amount) external onlyOwner {
    //     require(_amount <= rewardBalance(), "not enough rewards");
    //     // Withdraw rewards
    //     safeTransferReward(address(msg.sender), _amount);
    //     emit EmergencyRewardWithdraw(msg.sender, _amount);
    // }
}
