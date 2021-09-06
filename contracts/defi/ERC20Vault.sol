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
    uint256 public WITHDRAWAL_FEE_RATE = 300;

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
        IERC20 rewardToken; // Address of reward token contract.
        uint256 rewardUnit; // Reward tokens created per second.
        uint256 allocPoint; // How many allocation points assigned to this pool. Rewards to distribute per second.
        uint256 lastRewardTime; // Last time that Rewards distribution occurs.
        uint256 accRewardTokenPerShare; // Accumulated Rewards per share, times 1e30 (10**30). See below.
        uint256 totalStaked; // Keep track of number of tokens staked in case the contract earns reflect fees
        uint256 startTime;
        uint256 endTime;
        uint256 userCount;
    }

    mapping(uint256 => mapping(address => UserInfo)) poolUsers; // Info of each user that stakes LP tokens.
    PoolInfo[] public poolInfo; // pools
    uint256 public poolCount = 0;

    event Deposit(uint256 indexed poolId, address indexed user, uint256 amount);
    event DepositReward(uint256 indexed poolId, uint256 amount);
    event Withdraw(uint256 indexed poolId, address indexed user, uint256 amount);
    event WithdrawReward(uint256 indexed poolId, address indexed user, uint256 amount);
    event WithdrawStakedFee(uint256 indexed poolId, uint256 amount);
    event EmergencyWithdraw(uint256 indexed poolId, address indexed user, uint256 amount);
    event EmergencyWithdrawReward(uint256 indexed poolId, address indexed user, uint256 amount);

    receive() external payable {}

    constructor() {}

    /// Deposit staking token into the contract to earn rewards.
    /// @dev Since this contract needs to be supplied with rewards we are sending the balance of the contract if the pending rewards are higher
    /// @param _amount The amount of staking tokens to deposit
    function deposit(uint256 _pid, uint256 _amount) external payable {
        require(_pid < poolCount, "invalid pool id");
        require(_amount > 0, "invalid amount");
        require(isValidPool(_pid), "pool is invalid");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = poolUsers[_pid][msg.sender];
        _updatePoolRewardShare(_pid);
        uint256 pendingRewardBalance = _getPendingReward(user, pool.accRewardTokenPerShare);

        console.log("pool[%s] pendingReward : %s", _pid, pendingRewardBalance);

        bool isNew = (user.amount == 0);

        pool.stakeToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        pool.totalStaked += _amount;
        if (isNew) {
            pool.userCount += 1;
        }

        user.amount += _amount;
        user.rewardBalance = pendingRewardBalance;
        user.rewardDebt = user.amount.mul(pool.accRewardTokenPerShare).div(TOTAL_SHARE);

        emit Deposit(_pid, msg.sender, _amount);
    }

    /// Withdraw reward and/or staked tokens.
    /// @param _amount The amount of staking tokens to withdraw
    function withdraw(uint256 _pid, uint256 _amount) external payable {
        _withdraw(_pid, _amount);
    }

    /// Withdraw all .
    function withdrawAll(uint256 _pid) external payable {
        _withdraw(_pid, stakedBalanceOfUser(_pid, msg.sender));
    }

    function _withdraw(uint256 _pid, uint256 _amount) private {
        require(_pid < poolCount, "invalid pool id");
        require(_amount > 0, "invalid amount");

        uint256 userDepositAmount = stakedBalanceOfUser(_pid, msg.sender);
        console.log("userDepositAmount (ether) : %s", userDepositAmount);
        require(userDepositAmount >= _amount, "insufficient user deposit");
        require(stakedBalanceOfPool(_pid) >= _amount, "insufficient staked balance");

        _updatePoolRewardShare(_pid);

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = poolUsers[_pid][msg.sender];

        console.log("vault  : %s", pool.stakeToken.balanceOf(address(this)));
        console.log("_amount: %s", _amount);

        uint256 withdrawalFee = 0;
        if ((block.timestamp - user.depositTime) < 3 days) {
            withdrawalFee = (_amount * WITHDRAWAL_FEE_RATE) / TOTAL_ALLOC_POINT;
        }
        console.log("withdrawal fee: %s", withdrawalFee);

        console.log("withdraw amount: %s", _amount - withdrawalFee);
        pool.stakeToken.safeTransfer(address(msg.sender), _amount - withdrawalFee);

        pool.totalStaked -= _amount;
        uint256 userPendingReward = _getPendingReward(user, pool.accRewardTokenPerShare);
        bool isRemoved = (userDepositAmount == _amount);
        if (isRemoved) {
            console.log("withdraw reward: %s", userPendingReward);
            _safeTransferReward(_pid, address(msg.sender), userPendingReward);
            pool.userCount -= 1;
            user.amount = 0;
            user.rewardBalance = 0;
        } else {
            user.amount -= _amount;
            user.rewardBalance = userPendingReward;
        }

        user.rewardDebt = user.amount.mul(pool.accRewardTokenPerShare).div(TOTAL_SHARE);
        emit Withdraw(_pid, msg.sender, _amount);
    }

    function harvest(uint256 _pid) external payable {
        UserInfo storage user = poolUsers[_pid][msg.sender];

        uint256 userPendingReward = pendingReward(_pid, msg.sender);
        _safeTransferReward(_pid, address(msg.sender), userPendingReward);
        user.rewardBalance = 0;
    }

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
            uint256 tokenReward = multiplier.mul(pool.rewardUnit).mul(pool.allocPoint).div(TOTAL_ALLOC_POINT);
            accRewardTokenPerShare += tokenReward.mul(TOTAL_SHARE).div(pool.totalStaked);
        }

        return _getPendingReward(user, accRewardTokenPerShare);
    }

    function _getPendingReward(UserInfo memory user, uint256 _accRewardTokenPerShare) public view returns (uint256) {
        return user.amount.mul(_accRewardTokenPerShare).div(TOTAL_SHARE).add(user.rewardBalance).sub(user.rewardDebt);
    }

    // Return reward multiplier
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
        uint256 tokenReward = multiplier.mul(pool.rewardUnit).mul(pool.allocPoint).div(TOTAL_ALLOC_POINT);
        pool.accRewardTokenPerShare += tokenReward.mul(TOTAL_SHARE).div(pool.totalStaked);
        pool.lastRewardTime = block.timestamp;
    }

    function _safeTransferReward(
        uint256 _pid,
        address _to,
        uint256 _amount
    ) internal {
        require(_pid < poolCount, "invalid pool id");
        require(_amount > 0, "invalid amount");
        poolInfo[_pid].rewardToken.safeTransfer(_to, _amount);
        emit WithdrawReward(_pid, _to, _amount);
    }

    /* View Functions */

    function isValidPool(uint256 _pid) public view returns (bool) {
        PoolInfo memory pool = poolInfo[_pid];
        return pool.endTime > block.timestamp && pool.rewardUnit > 0;
    }

    function stakedBalanceOfUser(uint256 _pid, address _user) public view returns (uint256) {
        return poolUsers[_pid][_user].amount;
    }

    function stakedBalanceOfPool(uint256 _pid) public view returns (uint256) {
        return poolInfo[_pid].stakeToken.balanceOf(address(this));
    }

    function rewardBalanceOfPool(uint256 _pid) public view returns (uint256) {
        return poolInfo[_pid].rewardToken.balanceOf(address(this));
    }

    function stakedFeeOfPool(uint256 _pid) public view returns (uint256) {
        return stakedBalanceOfPool(_pid).sub(poolInfo[_pid].totalStaked);
    }

    function depositReward(uint256 _pid, uint256 _amount) external payable {
        require(_pid < poolCount, "invalid pool id");
        require(_amount > 0, "invalid amount");
        poolInfo[_pid].rewardToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        emit DepositReward(_pid, _amount);
    }

    /* Admin Functions */
    function newPool(
        IERC20 _stakeToken,
        IERC20 _rewardToken,
        uint256 _rewardUnit,
        uint256 _allocPoint,
        uint256 _startTime,
        uint256 _endTime
    ) external payable onlyOwner {
        poolInfo.push(
            PoolInfo({
                stakeToken: _stakeToken,
                rewardToken: _rewardToken,
                rewardUnit: _rewardUnit,
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
        uint256 _rewardUnit,
        uint256 _allocPoint,
        uint256 _startTime,
        uint256 _endTime
    ) external payable onlyOwner {
        PoolInfo storage pool = poolInfo[_pid];

        pool.rewardUnit = _rewardUnit;
        pool.allocPoint = _allocPoint;
        pool.startTime = _startTime;
        pool.lastRewardTime = _startTime;
        pool.endTime = _endTime;
    }

    function setRewardUnit(uint256 _pid, uint256 _rewardUnit) external onlyOwner {
        PoolInfo storage pool = poolInfo[_pid];

        pool.rewardUnit = _rewardUnit;
    }

    function setWithdrawFeeRate(uint256 _fee) external onlyOwner {
        WITHDRAWAL_FEE_RATE = _fee;
    }

    function withdrawReward(uint256 _pid, uint256 _amount) external onlyOwner {
        _safeTransferReward(_pid, msg.sender, _amount);
    }

    function withdrawStakedFee(uint256 _pid) external onlyOwner {
        require(_pid < poolCount, "invalid pool id");
        uint256 _amount = stakedFeeOfPool(_pid);
        require(_amount > 0, "invalid amount");
        poolInfo[_pid].stakeToken.safeTransfer(address(msg.sender), _amount);
        emit WithdrawStakedFee(_pid, _amount);
    }

    /* Emergency Functions */

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = poolUsers[_pid][msg.sender];
        require(user.amount <= stakedBalanceOfPool(_pid), "invalid user amount");
        pool.stakeToken.safeTransfer(address(msg.sender), user.amount);
        pool.totalStaked -= user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        user.rewardBalance = 0;
        emit EmergencyWithdraw(_pid, msg.sender, user.amount);
    }

    // Withdraw reward. EMERGENCY ONLY.
    function emergencyWithdrawReward(uint256 _pid) external onlyOwner {
        uint256 _amount = rewardBalanceOfPool(_pid);
        _safeTransferReward(_pid, address(msg.sender), _amount);
        emit EmergencyWithdrawReward(_pid, msg.sender, _amount);
    }
}
