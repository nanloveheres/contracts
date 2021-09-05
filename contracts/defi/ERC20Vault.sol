//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../utils/AdminRole.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ERC20Vault is AdminRole {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public TOTAL_ALLOC_POINT = 10000; // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public TOTAL_SHARE = 1e30;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
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

    // View function to see pending Reward on frontend.
    function pendingReward(uint256 _pid, address _user) public view returns (uint256) {
        PoolInfo memory pool = poolInfo[_pid];
        UserInfo memory user = poolUsers[_pid][_user];
        if (user.amount == 0) {
            return 0;
        }

        uint256 accRewardTokenPerShare = pool.accRewardTokenPerShare;
        if (block.timestamp > pool.startTime && block.timestamp > user.depositTime) {
            uint256 multiplier = _getMultiplier(_pid, user.depositTime, block.timestamp);
            uint256 tokenReward = multiplier.mul(rewardUnit).mul(pool.allocPoint).div(TOTAL_ALLOC_POINT);
            accRewardTokenPerShare += tokenReward.mul(TOTAL_SHARE).div(pool.totalStaked);
        }

        return user.amount.mul(accRewardTokenPerShare).div(TOTAL_SHARE);
    }

    // // Update reward variables of the given pool to be up-to-date.
    // function updatePool(uint256 _pid) public {
    //     PoolInfo storage pool = poolInfo[_pid];
    //     if (block.timestamp <= pool.lastRewardTime) {
    //         return;
    //     }
    //     if (totalStaked == 0) {
    //         pool.lastRewardTime = block.timestamp;
    //         return;
    //     }
    //     uint256 multiplier = getMultiplier(pool.lastRewardTime, block.timestamp);
    //     uint256 tokenReward = multiplier.mul(rewardUnit).mul(pool.allocPoint).div(totalAllocPoint);
    //     pool.accRewardTokenPerShare = pool.accRewardTokenPerShare.add(tokenReward.mul(TOTAL_SHARE).div(totalStaked));
    //     pool.lastRewardTime = block.timestamp;
    // }

    // // Update reward variables for all pools. Be careful of gas spending!
    // function massUpdatePools() public {
    //     uint256 length = poolInfo.length;
    //     for (uint256 pid = 0; pid < length; ++pid) {
    //         updatePool(pid);
    //     }
    // }

    function getDepositAmount(uint256 _pid, address _user) public view returns (uint256) {
        return poolUsers[_pid][_user].amount;
    }

    /// Deposit staking token into the contract to earn rewards.
    /// @dev Since this contract needs to be supplied with rewards we are
    ///  sending the balance of the contract if the pending rewards are higher
    /// @param _amount The amount of staking tokens to deposit
    function deposit(uint256 _pid, uint256 _amount) external payable {
        require(_pid < poolCount, "invalid pool id");
        require(_amount > 0, "invalid amount");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = poolUsers[_pid][msg.sender];
        bool isNew = (user.amount == 0);
        // uint256 finalDepositAmount = 0;
        // updatePool(_pid);
        // if (user.amount > 0) {
        //     uint256 pending = user.amount.mul(pool.accRewardTokenPerShare).div(TOTAL_SHARE).sub(user.rewardDebt);
        //     if (pending > 0) {
        //         uint256 currentRewardBalance = rewardBalance();
        //         if (currentRewardBalance > 0) {
        //             if (pending > currentRewardBalance) {
        //                 safeTransferReward(_pid, address(msg.sender), currentRewardBalance);
        //             } else {
        //                 safeTransferReward(_pid, address(msg.sender), pending);
        //             }
        //         }
        //     }
        // }

        // uint256 preStakeBalance = totalStakeTokenBalance();
        // finalDepositAmount = totalStakeTokenBalance().sub(preStakeBalance);

        // user.rewardDebt = user.amount.mul(pool.accRewardTokenPerShare).div(TOTAL_SHARE);

        pool.stakeToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        pool.totalStaked += _amount;
        if (isNew) {
            pool.userCount += 1;
        }

        user.amount += _amount;
        user.rewardDebt += pendingReward(_pid, msg.sender);
        user.depositTime = block.timestamp;

        emit Deposit(_pid, msg.sender, _amount);
    }

    // /// Withdraw rewards and/or staked tokens. Pass a 0 amount to withdraw only rewards
    // /// @param _amount The amount of staking tokens to withdraw
    // function withdraw(uint256 _amount) external payable {
    //     PoolInfo storage pool = poolInfo[0];
    //     UserInfo storage user = pool.users[msg.sender];
    //     require(user.amount >= _amount, "withdraw: not good");
    //     updatePool(0);
    //     uint256 pending = user.amount.mul(pool.accRewardTokenPerShare).div(TOTAL_SHARE).sub(user.rewardDebt);
    //     if (pending > 0) {
    //         uint256 currentRewardBalance = rewardBalance();
    //         if (currentRewardBalance > 0) {
    //             if (pending > currentRewardBalance) {
    //                 safeTransferReward(address(msg.sender), currentRewardBalance);
    //             } else {
    //                 safeTransferReward(address(msg.sender), pending);
    //             }
    //         }
    //     }
    //     if (_amount > 0) {
    //         user.amount = user.amount.sub(_amount);
    //         pool.stakeToken.safeTransfer(address(msg.sender), _amount);
    //         totalStaked = totalStaked.sub(_amount);
    //     }

    //     user.rewardDebt = user.amount.mul(pool.accRewardTokenPerShare).div(TOTAL_SHARE);

    //     emit Withdraw(msg.sender, _amount);
    // }

    function rewardBalance(uint256 _pid) public view returns (uint256) {
        return poolInfo[_pid].rewardToken.balanceOf(address(this));
    }

    // Deposit Rewards into contract
    function depositRewards(uint256 _pid, uint256 _amount) external {
        require(_amount > 0, "Deposit value must be greater than 0.");
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
    ) external payable onlyOwner returns (uint256) {
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

        return poolCount - 1;
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
