//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../utils/AdminRole.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ERC20Vault is AdminRole {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 stakeToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. Rewards to distribute per second.
        uint256 lastRewardTime; // Last time that Rewards distribution occurs.
        uint256 accRewardTokenPerShare; // Accumulated Rewards per share, times 1e30 (10**30). See below.
        uint256 totalStaked;       
        mapping(address => UserInfo) userInfo;  // Info of each user that stakes LP tokens.
    }

    IERC20 public stakeToken;
    IERC20 public rewardToken;

    // Reward tokens created per second.
    uint256 public rewardUnit;

    // Keep track of number of tokens staked in case the contract earns reflect fees
    uint256 public totalStaked = 0;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 private totalAllocPoint = 0;
    uint256 public poolStartTime;
    uint256 public bonusEndTime;

    event Deposit(address indexed user, uint256 amount);
    event DepositRewards(uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event EmergencyRewardWithdraw(address indexed user, uint256 amount);
    event SkimStakeTokenFees(address indexed user, uint256 amount);

    receive() external payable {}

    constructor(
        IERC20 _stakeToken,
        IERC20 _rewardToken,
        uint256 _rewardUnit,
        uint256 _poolStartTime,
        uint256 _bonusEndTime
    ) {
        stakeToken = _stakeToken;
        rewardToken = _rewardToken;
        rewardUnit = _rewardUnit;
        poolStartTime = _poolStartTime;
        bonusEndTime = _bonusEndTime;

        poolInfo.push(PoolInfo({ stakeToken: _stakeToken, allocPoint: 1000, lastRewardTime: poolStartTime, accRewardTokenPerShare: 0, totalStaked: 0 }));

        totalAllocPoint = 1000;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        if (_to <= bonusEndTime) {
            return _to.sub(_from);
        } else if (_from >= bonusEndTime) {
            return 0;
        } else {
            return bonusEndTime.sub(_from);
        }
    }

    // View function to see pending Reward on frontend.
    function pendingReward(address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[_user];
        uint256 accRewardTokenPerShare = pool.accRewardTokenPerShare;
        if (block.timestamp > pool.lastRewardTime && totalStaked != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardTime, block.timestamp);
            uint256 tokenReward = multiplier.mul(rewardUnit).mul(pool.allocPoint).div(totalAllocPoint);
            accRewardTokenPerShare = accRewardTokenPerShare.add(tokenReward.mul(1e30).div(totalStaked));
        }
        return user.amount.mul(accRewardTokenPerShare).div(1e30).sub(user.rewardDebt);
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }
        if (totalStaked == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardTime, block.timestamp);
        uint256 tokenReward = multiplier.mul(rewardUnit).mul(pool.allocPoint).div(totalAllocPoint);
        pool.accRewardTokenPerShare = pool.accRewardTokenPerShare.add(tokenReward.mul(1e30).div(totalStaked));
        pool.lastRewardTime = block.timestamp;
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    /// Deposit staking token into the contract to earn rewards.
    /// @dev Since this contract needs to be supplied with rewards we are
    ///  sending the balance of the contract if the pending rewards are higher
    /// @param _amount The amount of staking tokens to deposit
    function deposit(uint256 _amount) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[msg.sender];
        uint256 finalDepositAmount = 0;
        updatePool(0);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accRewardTokenPerShare).div(1e30).sub(user.rewardDebt);
            if (pending > 0) {
                uint256 currentRewardBalance = rewardBalance();
                if (currentRewardBalance > 0) {
                    if (pending > currentRewardBalance) {
                        safeTransferReward(address(msg.sender), currentRewardBalance);
                    } else {
                        safeTransferReward(address(msg.sender), pending);
                    }
                }
            }
        }
        if (_amount > 0) {
            uint256 preStakeBalance = totalStakeTokenBalance();
            pool.stakeToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            finalDepositAmount = totalStakeTokenBalance().sub(preStakeBalance);
            user.amount = user.amount.add(finalDepositAmount);
            totalStaked = totalStaked.add(finalDepositAmount);
        }
        user.rewardDebt = user.amount.mul(pool.accRewardTokenPerShare).div(1e30);

        emit Deposit(msg.sender, finalDepositAmount);
    }

    /// Withdraw rewards and/or staked tokens. Pass a 0 amount to withdraw only rewards
    /// @param _amount The amount of staking tokens to withdraw
    function withdraw(uint256 _amount) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(0);
        uint256 pending = user.amount.mul(pool.accRewardTokenPerShare).div(1e30).sub(user.rewardDebt);
        if (pending > 0) {
            uint256 currentRewardBalance = rewardBalance();
            if (currentRewardBalance > 0) {
                if (pending > currentRewardBalance) {
                    safeTransferReward(address(msg.sender), currentRewardBalance);
                } else {
                    safeTransferReward(address(msg.sender), pending);
                }
            }
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.stakeToken.safeTransfer(address(msg.sender), _amount);
            totalStaked = totalStaked.sub(_amount);
        }

        user.rewardDebt = user.amount.mul(pool.accRewardTokenPerShare).div(1e30);

        emit Withdraw(msg.sender, _amount);
    }

    /// Obtain the reward balance of this contract
    /// @return wei balace of conract
    function rewardBalance() public view returns (uint256) {
        return rewardToken.balanceOf(address(this));
    }

    // Deposit Rewards into contract
    function depositRewards(uint256 _amount) external {
        require(_amount > 0, "Deposit value must be greater than 0.");
        rewardToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        emit DepositRewards(_amount);
    }

    /// @param _to address to send reward token to
    /// @param _amount value of reward token to transfer
    function safeTransferReward(address _to, uint256 _amount) internal {
        rewardToken.safeTransfer(_to, _amount);
    }

    /* Admin Functions */

    /// @param _rewardUnit The amount of reward tokens to be given per block
    function setRewardUnit(uint256 _rewardUnit) external onlyOwner {
        rewardUnit = _rewardUnit;
    }

    /// @param  _bonusEndTime The block when rewards will end
    function setBonusEndTime(uint256 _bonusEndTime) external onlyOwner {
        require(_bonusEndTime > bonusEndTime, "new bonus end block must be greater than current");
        bonusEndTime = _bonusEndTime;
    }

    /// @dev Obtain the stake token fees (if any) earned by reflect token
    function getStakeTokenFeeBalance() public view returns (uint256) {
        return totalStakeTokenBalance().sub(totalStaked);
    }

    /// @dev Obtain the stake balance of this contract
    /// @return wei balace of contract
    function totalStakeTokenBalance() public view returns (uint256) {
        // Return BEO20 balance
        return stakeToken.balanceOf(address(this));
    }

    /// @dev Remove excess stake tokens earned by reflect fees
    function skimStakeTokenFees() external onlyOwner {
        uint256 stakeTokenFeeBalance = getStakeTokenFeeBalance();
        stakeToken.safeTransfer(msg.sender, stakeTokenFeeBalance);
        emit SkimStakeTokenFees(msg.sender, stakeTokenFeeBalance);
    }

    /* Emergency Functions */

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() external {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[msg.sender];
        pool.stakeToken.safeTransfer(address(msg.sender), user.amount);
        totalStaked = totalStaked.sub(user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
        emit EmergencyWithdraw(msg.sender, user.amount);
    }

    // Withdraw reward. EMERGENCY ONLY.
    function emergencyRewardWithdraw(uint256 _amount) external onlyOwner {
        require(_amount <= rewardBalance(), "not enough rewards");
        // Withdraw rewards
        safeTransferReward(address(msg.sender), _amount);
        emit EmergencyRewardWithdraw(msg.sender, _amount);
    }
}
