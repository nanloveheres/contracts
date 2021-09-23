//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "hardhat/console.sol";
import "../utils/AdminRole.sol";

interface IMigratorChef {
    // Perform LP token migration from legacy PancakeSwap to CakeSwap.
    // Take the current LP token address and return the new LP token address.
    // Migrator should have full access to the caller's LP token.
    // Return the new LP token address.
    //
    // XXX Migrator must have allowance access to PancakeSwap LP tokens.
    // CakeSwap must mint EXACTLY the same amount of CakeSwap LP tokens or
    // else something bad will happen. Traditional PancakeSwap does not
    // do that so be careful!
    function migrate(IERC20 token) external returns (IERC20);
}

// MasterChef is the master of Cake. He can make Cake and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once CAKE is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChef is AdminRole, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 depositTime;
        //
        // We do some fancy math here. Basically, any point in time, the amount of CAKEs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accRewardPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accRewardPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 stakeToken; // Address of LP token contract.
        IERC20 rewardToken;
        uint256 allocPoint; // How many allocation points assigned to this pool. CAKEs to distribute per block.
        uint256 lastRewardBlock; // Last block number that CAKEs distribution occurs.
        uint256 accRewardPerShare; // Accumulated CAKEs per share, times 1e12. See below.
        uint256 rewardUnit; // Reward tokens created per second.
    }

    uint256 public TOTAL_PERCENT = 10000;
    uint256 public WITHDRAWAL_FEE_RATE = 300;
    // Bonus muliplier for early cake makers.
    uint256 public BONUS_MULTIPLIER = 1;
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public migrator;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when CAKE mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event DepositReward(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event WithdrawReward(address indexed user, uint256 indexed pid, uint256 amount);
    event WithdrawStakedFee(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdrawReward(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        IERC20 _syrupToken,
        uint256 _rewardUnit,
        uint256 _startBlock
    ) {
        startBlock = _startBlock;
        add(_syrupToken, _syrupToken, _rewardUnit, 1000, false);
    }

    function setRewardUnit(uint256 _pid, uint256 _rewardUnit) external onlyOwner {
        PoolInfo storage pool = poolInfo[_pid];

        pool.rewardUnit = _rewardUnit;
    }

    function setWithdrawFeeRate(uint256 _fee) external onlyOwner {
        WITHDRAWAL_FEE_RATE = _fee;
    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        IERC20 _stakeToken,
        IERC20 _rewardToken,
        uint256 _rewardUnit,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.timestamp > startBlock ? block.timestamp : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                stakeToken: _stakeToken,
                rewardToken: _rewardToken,
                rewardUnit: _rewardUnit,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accRewardPerShare: 0
            })
        );
        updateStakingPool();
    }

    // Update the given pool's CAKE allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        if (prevAllocPoint != _allocPoint) {
            poolInfo[_pid].allocPoint = _allocPoint;
            totalAllocPoint = totalAllocPoint.sub(prevAllocPoint).add(_allocPoint);
            updateStakingPool();
        }
    }

    function updateStakingPool() internal {
        uint256 length = poolInfo.length;
        uint256 points = 0;
        for (uint256 pid = 1; pid < length; ++pid) {
            points = points.add(poolInfo[pid].allocPoint);
        }
        if (points != 0) {
            points = points.div(3);
            totalAllocPoint = totalAllocPoint.sub(poolInfo[0].allocPoint).add(points);
            poolInfo[0].allocPoint = points;
        }
    }

    // Set the migrator contract. Can only be called by the owner.
    function setMigrator(IMigratorChef _migrator) public onlyOwner {
        migrator = _migrator;
    }

    // Migrate lp token to another lp contract. Can be called by anyone. We trust that migrator contract is good.
    function migrate(uint256 _pid) public {
        require(address(migrator) != address(0), "migrate: no migrator");
        PoolInfo storage pool = poolInfo[_pid];
        IERC20 stakeToken = pool.stakeToken;
        uint256 bal = stakeToken.balanceOf(address(this));
        stakeToken.safeApprove(address(migrator), bal);
        IERC20 newLpToken = migrator.migrate(stakeToken);
        require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
        pool.stakeToken = newLpToken;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending CAKEs on frontend.
    function pendingReward(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        uint256 lpSupply = pool.stakeToken.balanceOf(address(this));
        if (block.timestamp > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.timestamp);
            uint256 cakeReward = multiplier.mul(pool.rewardUnit).mul(pool.allocPoint).div(totalAllocPoint);
            accRewardPerShare = accRewardPerShare.add(cakeReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accRewardPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.stakeToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.timestamp;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.timestamp);
        uint256 cakeReward = multiplier.mul(pool.rewardUnit).mul(pool.allocPoint).div(totalAllocPoint);
        pool.accRewardPerShare = pool.accRewardPerShare.add(cakeReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.timestamp;
    }

    // Deposit LP tokens to MasterChef for CAKE allocation.
    function deposit(uint256 _pid, uint256 _amount) public nonReentrant {
        require(_pid < poolInfo.length, "invalid pid");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accRewardPerShare).div(1e12).sub(user.rewardDebt);
            if (pending > 0) {
                _safeTransferReward(_pid, msg.sender, pending);
            }
        }
        if (_amount > 0) {
            // console.log("amount: %s", _amount / (1 ether));
            // console.log("sender bal: %s", pool.stakeToken.balanceOf(msg.sender) / (1 ether));
            pool.stakeToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
            user.depositTime = block.timestamp;
        }
        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public nonReentrant {
        require(_pid < poolInfo.length, "invalid pid");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accRewardPerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            _safeTransferReward(_pid, msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);

            uint256 withdrawalFee = 0;
            if ((block.timestamp - user.depositTime) < 3 days) {
                withdrawalFee = (_amount * WITHDRAWAL_FEE_RATE) / TOTAL_PERCENT;
            }
            // console.log("withdrawal fee: %s", withdrawalFee);
            // console.log("withdraw amount: %s", _amount - withdrawalFee);
            pool.stakeToken.safeTransfer(address(msg.sender), _amount - withdrawalFee);
            pool.stakeToken.safeTransfer(owner, withdrawalFee);
        }
        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Stake CAKE tokens to MasterChef
    function enterStaking(uint256 _amount) public {
        deposit(0, _amount);
    }

    // Withdraw CAKE tokens from STAKING.
    function leaveStaking(uint256 _amount) public {
        withdraw(0, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.stakeToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    function depositReward(uint256 _pid, uint256 _amount) external payable {
        require(_pid < poolInfo.length, "invalid pool id");
        require(_amount > 0, "invalid amount");
        poolInfo[_pid].rewardToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        emit DepositReward(msg.sender, _pid, _amount);
    }

    function _safeTransferReward(
        uint256 _pid,
        address _to,
        uint256 _amount
    ) internal {
        require(_pid < poolInfo.length, "invalid pool id");
        require(_amount > 0, "invalid amount");
        poolInfo[_pid].rewardToken.safeTransfer(_to, _amount);
        emit WithdrawReward(_to, _pid, _amount);
    }

    function withdrawReward(uint256 _pid, uint256 _amount) external onlyOwner {
        _safeTransferReward(_pid, msg.sender, _amount);
    }

    // Withdraw reward. EMERGENCY ONLY.
    function emergencyWithdrawReward(uint256 _pid) external onlyOwner {
        uint256 _amount = rewardBalanceOfPool(_pid);
        _safeTransferReward(_pid, address(msg.sender), _amount);
        emit EmergencyWithdrawReward(msg.sender, _pid, _amount);
    }

    /* View Functions */

    function isValidPool(uint256 _pid) public view returns (bool) {
        PoolInfo memory pool = poolInfo[_pid];
        return pool.rewardUnit > 0;
    }

    function stakedBalanceOfUser(uint256 _pid, address _user) public view returns (uint256) {
        return userInfo[_pid][_user].amount;
    }

    function stakedBalanceOfPool(uint256 _pid) public view returns (uint256) {
        return poolInfo[_pid].stakeToken.balanceOf(address(this));
    }

    function rewardBalanceOfPool(uint256 _pid) public view returns (uint256) {
        return poolInfo[_pid].rewardToken.balanceOf(address(this));
    }
}
