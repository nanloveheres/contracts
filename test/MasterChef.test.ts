import chai, { expect } from "chai"
import { Contract } from "ethers"
import { ether, toEther, parseUnits, mineTime } from "./shared/util"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { network, ethers } from "hardhat"

describe("MasterChef", () => {
    let owner: SignerWithAddress
    let alice: SignerWithAddress
    let bob: SignerWithAddress

    let stakeToken: Contract
    let lpToken: Contract
    let rewardToken: Contract
    let chef: Contract

    const POOL_ID = 1
    const REWARD_UNIT = ether(1)

    beforeEach(async () => {
        ;[owner, alice, bob] = await ethers.getSigners()
        const ERC20Token = await ethers.getContractFactory("ERC20Token")
        const RewardToken = await ethers.getContractFactory("RewardToken")
        const MasterChef = await ethers.getContractFactory("MasterChef")
        stakeToken = await ERC20Token.deploy()
        lpToken = await ERC20Token.deploy()
        rewardToken = await RewardToken.deploy()

        const blockNumber = await ethers.provider.getBlockNumber()
        const block = await ethers.provider.getBlock(blockNumber)
        const startTime = block.timestamp
        const share = 1000

        chef = await MasterChef.deploy(rewardToken.address, REWARD_UNIT, startTime)
        await chef.add(stakeToken.address, rewardToken.address, REWARD_UNIT, share, false)

        const totalSupply = await rewardToken.totalSupply()
        await rewardToken.approve(chef.address, totalSupply)
        await chef.depositReward(0, totalSupply)
    })

    it("Is valid pool", async () => {
        const blockNumber = await ethers.provider.getBlockNumber()
        const block = await ethers.provider.getBlock(blockNumber)
        const now = block.timestamp

        const pool = await chef.poolInfo(POOL_ID)
        expect(pool.accRewardPerShare, "accRewardPerShare = 0").to.eq(0)
        expect(pool.lastRewardBlock, "lastRewardBlock < now").to.lte(now)
        // console.info(`pool: `, pool)

        expect(await chef.isValidPool(0), "pool 0 is valid").to.eq(true)
        expect(await chef.isValidPool(POOL_ID), "pool 1 is valid").to.eq(true)
        await expect(chef.isValidPool(2), "pool 2 isn't valid").to.be.reverted

        await chef.setRewardUnit(POOL_ID, 0)
        expect(await chef.isValidPool(POOL_ID), "pool 1 isn't valid").to.eq(false)
    })

    it("Adds new pool", async () => {
        expect(await chef.poolLength(), "pool count = 2").to.eq(2)
        await chef.add(lpToken.address, rewardToken.address, REWARD_UNIT, 100, false)
        expect(await chef.poolLength(), "pool count = 3").to.eq(3)

        const blockNumber = await ethers.provider.getBlockNumber()
        const block = await ethers.provider.getBlock(blockNumber)
        const now = block.timestamp

        let pool = await chef.poolInfo(2)
        expect(pool.allocPoint, "allocPoint").to.eq(100)
        expect(pool.accRewardPerShare, "accRewardPerShare").to.eq(0)
        expect(pool.lastRewardBlock, "lastRewardBlock < now").to.lte(now)

        expect(await chef.isValidPool(POOL_ID), "pool 1 is valid").to.eq(true)
        expect(await chef.isValidPool(2), "pool 2 is valid").to.eq(true)

        await lpToken.transfer(alice.address, ether(2000))
        await lpToken.connect(alice).approve(chef.address, ether(2000000))

        await chef.connect(alice).deposit(2, ether(1000))
        expect(pool.accRewardPerShare, "accRewardPerShare = 0").to.eq(0)

        await chef.connect(alice).deposit(2, ether(1000))
        // await mineTime(3600)
        pool = await chef.poolInfo(2)
        expect(pool.accRewardPerShare, "accRewardPerShare > 0").to.gt(0)
    })

    it("Check stake token balance", async () => {
        await stakeToken.transfer(alice.address, ether(1000))
        expect(await stakeToken.balanceOf(alice.address)).to.eq(ether(1000))
    })

    // it("One deposit", async () => {
    //     await stakeToken.transfer(alice.address, ether(1000))
    //     await stakeToken.connect(alice).approve(chef.address, ether(1000))
    //     await chef.connect(alice).deposit(POOL_ID, ether(1000))

    //     let pendingReward = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (begin): ${toEther(pendingReward)}`)
    //     await mineTime(3600)
    //     pendingReward = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (after 1h): ${toEther(pendingReward)}`)
    //     await mineTime(3600 * 23)
    //     pendingReward = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (after 24h): ${toEther(pendingReward)}`)
    //     await mineTime(3600 * 23 * 30)
    //     pendingReward = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (after 30d): ${toEther(pendingReward)}`)

    //     expect(pendingReward).to.gt(0)
    // })

    // it("Deposit & Withdraw", async () => {
    //     await rewardToken.approve(chef.address, ether(100000000))
    //     await chef.depositReward(POOL_ID, ether(100000000))

    //     await stakeToken.transfer(alice.address, ether(1000))
    //     await stakeToken.connect(alice).approve(chef.address, ether(1000))
    //     await chef.connect(alice).deposit(POOL_ID, ether(1000))

    //     let pendingReward = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (begin): ${toEther(pendingReward)}`)
    //     await mineTime(3600)
    //     pendingReward = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (after 1h): ${toEther(pendingReward)}`)

    //     console.info(`withdraw: 500`)
    //     await chef.connect(alice).withdraw(POOL_ID, ether(500))
    //     pendingReward = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward: ${toEther(pendingReward)}`)

    //     await mineTime(3600)
    //     pendingReward = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (after 1h): ${toEther(pendingReward)}`)

    //     console.info(`withdraw: all`)
    //     await chef.connect(alice).withdrawAll(POOL_ID)
    //     pendingReward = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward: ${toEther(pendingReward)}`)

    //     await mineTime(3600)
    //     pendingReward = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (after 1h): ${toEther(pendingReward)}`)

    //     console.info(`deposit: 100`)
    //     await stakeToken.connect(alice).approve(chef.address, ether(1000))
    //     await chef.connect(alice).deposit(POOL_ID, ether(100))
    //     pendingReward = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward: ${toEther(pendingReward)}`)

    //     await mineTime(3600)
    //     pendingReward = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (after 1h): ${toEther(pendingReward)}`)

    //     expect(pendingReward).to.gt(0)
    // })

    // it("Deposit + Harvest", async () => {
    //     await rewardToken.approve(chef.address, ether(100000000))
    //     await chef.depositReward(POOL_ID, ether(100000000))

    //     await stakeToken.transfer(alice.address, ether(2000))
    //     await stakeToken.connect(alice).approve(chef.address, ether(2000))
    //     await chef.connect(alice).deposit(POOL_ID, ether(1000))

    //     let pendingReward = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (begin): ${toEther(pendingReward)}`)
    //     await mineTime(3600)
    //     pendingReward = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (after 1h): ${toEther(pendingReward)}`)

    //     await chef.connect(alice).harvest(POOL_ID)
    //     const lastReward = pendingReward
    //     pendingReward = await chef.pendingReward(POOL_ID, alice.address)
    //     expect(pendingReward, `pendingReward (after harvest: ${toEther(pendingReward)} <= lastReward ${toEther(lastReward)}`).to.lte(lastReward)

    //     const receivedReward = await rewardToken.balanceOf(alice.address)
    //     expect(receivedReward, "receivedReward>=lastReward").to.gte(lastReward)

    //     await mineTime(3600)
    //     pendingReward = await chef.pendingReward(POOL_ID, alice.address)
    //     expect(pendingReward, `pendingReward (after 1h): ${toEther(pendingReward)}`).to.gte(ether(3600))
    //     expect(pendingReward, `pendingReward (after 1h): ${toEther(pendingReward)}`).to.lt(ether(3610))
    // })

    // it("Two deposits + Harvest", async () => {
    //     await rewardToken.approve(chef.address, ether(100000000))
    //     await chef.depositReward(POOL_ID, ether(100000000))

    //     await stakeToken.transfer(alice.address, ether(2000))
    //     await stakeToken.connect(alice).approve(chef.address, ether(2000))
    //     await chef.connect(alice).deposit(POOL_ID, ether(1000))

    //     await stakeToken.transfer(bob.address, ether(2000))
    //     await stakeToken.connect(bob).approve(chef.address, ether(2000))
    //     await chef.connect(bob).deposit(POOL_ID, ether(2000))

    //     let rewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`alice reward (begin): ${toEther(rewardAlice)}`)
    //     await mineTime(3600)
    //     rewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`alice reward (after 1h): ${toEther(rewardAlice)}`)

    //     let rewardBob = await chef.pendingReward(POOL_ID, bob.address)
    //     expect(rewardBob, "bob reward (after 1h):").to.gt(rewardAlice)

    //     await chef.connect(alice).harvest(POOL_ID)
    //     const lastRewardAlice = rewardAlice
    //     rewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     expect(rewardAlice, `alice reward (after harvest: ${toEther(rewardAlice)} <= lastReward ${toEther(lastRewardAlice)}`).to.lte(lastRewardAlice)

    //     const lastRewardBob = rewardBob
    //     rewardBob = await await chef.pendingReward(POOL_ID, bob.address)
    //     expect(rewardBob, `bob reward (after harvest: ${toEther(rewardBob)}>= lastReward ${toEther(lastRewardBob)}`).to.gte(lastRewardBob)

    //     await mineTime(3600)

    //     rewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`alice reward (after 1h): ${toEther(rewardAlice)}`)
    //     expect(rewardAlice, `alice reward (after 1h): ${toEther(rewardAlice)} > 0`).to.gt(0)
    //     expect(rewardAlice, `alice reward (after 1h): ${toEther(rewardAlice)} < 2000`).to.lt(ether(2000))

    //     rewardBob = await await chef.pendingReward(POOL_ID, bob.address)
    //     console.info(`bob reward (after 1h): ${toEther(rewardBob)}`)
    //     expect(rewardBob, `bob reward (after 1h): ${toEther(rewardBob)}`).to.gt(lastRewardBob)
    // })

    // it("Two deposits (same time)", async () => {
    //     await stakeToken.transfer(alice.address, ether(1000))
    //     await stakeToken.connect(alice).approve(chef.address, ether(1000))
    //     await chef.connect(alice).deposit(POOL_ID, ether(1000))

    //     await stakeToken.transfer(bob.address, ether(2000))
    //     await stakeToken.connect(bob).approve(chef.address, ether(2000))
    //     await chef.connect(bob).deposit(POOL_ID, ether(2000))

    //     const blockNumber = await ethers.provider.getBlockNumber()
    //     const block = await ethers.provider.getBlock(blockNumber)
    //     const startTime = block.timestamp
    //     const endTime = block.timestamp + 3600 * 24 * 100
    //     await chef.updatePool(POOL_ID, REWARD_UNIT, 10000, startTime, endTime)

    //     let pendingRewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (alice, begin): ${toEther(pendingRewardAlice)}`)
    //     let pendingRewardBob = await chef.pendingReward(POOL_ID, bob.address)
    //     console.info(`pendingReward (bob, begin): ${toEther(pendingRewardBob)}`)

    //     await mineTime(3600)
    //     pendingRewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (alice, after 1h): ${toEther(pendingRewardAlice)}`)
    //     pendingRewardBob = await chef.pendingReward(POOL_ID, bob.address)
    //     console.info(`pendingReward (bob, after 1h): ${toEther(pendingRewardBob)}`)

    //     await mineTime(3600 * 23)
    //     pendingRewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (alice, after 24h): ${toEther(pendingRewardAlice)}`)
    //     pendingRewardBob = await chef.pendingReward(POOL_ID, bob.address)
    //     console.info(`pendingReward (bob, after 24h): ${toEther(pendingRewardBob)}`)

    //     await mineTime(3600 * 24 * 29)
    //     pendingRewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (alice, after 30d): ${toEther(pendingRewardAlice)}`)
    //     pendingRewardBob = await chef.pendingReward(POOL_ID, bob.address)
    //     console.info(`pendingReward (bob, after 30d): ${toEther(pendingRewardBob)}`)

    //     expect(pendingRewardAlice).to.gt(0)
    //     expect(pendingRewardBob).to.gt(0)
    // })

    // it("Two deposits (diff time) ", async () => {
    //     await stakeToken.transfer(alice.address, ether(1000))
    //     await stakeToken.connect(alice).approve(chef.address, ether(1000))
    //     await chef.connect(alice).deposit(POOL_ID, ether(1000))

    //     await stakeToken.transfer(bob.address, ether(2000))
    //     await stakeToken.connect(bob).approve(chef.address, ether(2000))

    //     const blockNumber = await ethers.provider.getBlockNumber()
    //     const block = await ethers.provider.getBlock(blockNumber)
    //     const startTime = block.timestamp
    //     const endTime = block.timestamp + 3600 * 24 * 100
    //     await chef.updatePool(POOL_ID, REWARD_UNIT, 10000, startTime, endTime)

    //     await mineTime(3600)
    //     await chef.connect(bob).deposit(POOL_ID, ether(2000))

    //     let pendingRewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (alice, begin): ${toEther(pendingRewardAlice)}`)
    //     let pendingRewardBob = await chef.pendingReward(POOL_ID, bob.address)
    //     console.info(`pendingReward (bob, begin): ${toEther(pendingRewardBob)}`)

    //     await mineTime(3600)
    //     pendingRewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (alice, after 1h): ${toEther(pendingRewardAlice)}`)
    //     pendingRewardBob = await chef.pendingReward(POOL_ID, bob.address)
    //     console.info(`pendingReward (bob, after 1h): ${toEther(pendingRewardBob)}`)

    //     await mineTime(3600)
    //     pendingRewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (alice, after 2h): ${toEther(pendingRewardAlice)}`)
    //     pendingRewardBob = await chef.pendingReward(POOL_ID, bob.address)
    //     console.info(`pendingReward (bob, after 2h): ${toEther(pendingRewardBob)}`)

    //     await mineTime(3600)
    //     pendingRewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (alice, after 3h): ${toEther(pendingRewardAlice)}`)
    //     pendingRewardBob = await chef.pendingReward(POOL_ID, bob.address)
    //     console.info(`pendingReward (bob, after 3h): ${toEther(pendingRewardBob)}`)

    //     await mineTime(3600 * 7)
    //     pendingRewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (alice, after 10h): ${toEther(pendingRewardAlice)}`)
    //     pendingRewardBob = await chef.pendingReward(POOL_ID, bob.address)
    //     console.info(`pendingReward (bob, after 10h): ${toEther(pendingRewardBob)}`)

    //     await mineTime(3600 * 24 * 29)
    //     pendingRewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (alice, after 30d): ${toEther(pendingRewardAlice)}`)
    //     pendingRewardBob = await chef.pendingReward(POOL_ID, bob.address)
    //     console.info(`pendingReward (bob, after 30d): ${toEther(pendingRewardBob)}`)

    //     expect(pendingRewardAlice).to.gt(0)
    //     expect(pendingRewardBob).to.gt(0)
    // })

    // it("Two deposits (+ amount) ", async () => {
    //     await stakeToken.transfer(alice.address, ether(1000))
    //     await stakeToken.connect(alice).approve(chef.address, ether(1000))
    //     await chef.connect(alice).deposit(POOL_ID, ether(1000))

    //     await stakeToken.transfer(bob.address, ether(4000))
    //     await stakeToken.connect(bob).approve(chef.address, ether(4000))

    //     const blockNumber = await ethers.provider.getBlockNumber()
    //     const block = await ethers.provider.getBlock(blockNumber)
    //     const startTime = block.timestamp
    //     const endTime = block.timestamp + 3600 * 24 * 100
    //     await chef.updatePool(POOL_ID, REWARD_UNIT, 10000, startTime, endTime)

    //     await mineTime(3600)
    //     console.info(`bob adds 2000`)
    //     await chef.connect(bob).deposit(POOL_ID, ether(2000))

    //     let pendingRewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (alice, begin): ${toEther(pendingRewardAlice)}`)
    //     let pendingRewardBob = await chef.pendingReward(POOL_ID, bob.address)
    //     console.info(`pendingReward (bob, begin): ${toEther(pendingRewardBob)}`)

    //     await mineTime(3600)
    //     pendingRewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (alice, after 1h): ${toEther(pendingRewardAlice)}`)
    //     pendingRewardBob = await chef.pendingReward(POOL_ID, bob.address)
    //     console.info(`pendingReward (bob, after 1h): ${toEther(pendingRewardBob)}`)

    //     console.info(`bob adds 2000`)
    //     await chef.connect(bob).deposit(POOL_ID, ether(2000))

    //     pendingRewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (alice, after 1h): ${toEther(pendingRewardAlice)}`)
    //     pendingRewardBob = await chef.pendingReward(POOL_ID, bob.address)
    //     console.info(`pendingReward (bob, after 1h): ${toEther(pendingRewardBob)}`)

    //     await mineTime(3600)
    //     pendingRewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (alice, after 2h): ${toEther(pendingRewardAlice)}`)
    //     pendingRewardBob = await chef.pendingReward(POOL_ID, bob.address)
    //     console.info(`pendingReward (bob, after 2h): ${toEther(pendingRewardBob)}`)

    //     await mineTime(3600)
    //     pendingRewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (alice, after 3h): ${toEther(pendingRewardAlice)}`)
    //     pendingRewardBob = await chef.pendingReward(POOL_ID, bob.address)
    //     console.info(`pendingReward (bob, after 3h): ${toEther(pendingRewardBob)}`)

    //     await mineTime(3600 * 7)
    //     pendingRewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (alice, after 10h): ${toEther(pendingRewardAlice)}`)
    //     pendingRewardBob = await chef.pendingReward(POOL_ID, bob.address)
    //     console.info(`pendingReward (bob, after 10h): ${toEther(pendingRewardBob)}`)

    //     await mineTime(3600 * 24 * 29)
    //     pendingRewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (alice, after 30d): ${toEther(pendingRewardAlice)}`)
    //     pendingRewardBob = await chef.pendingReward(POOL_ID, bob.address)
    //     console.info(`pendingReward (bob, after 30d): ${toEther(pendingRewardBob)}`)

    //     expect(pendingRewardAlice).to.gt(0)
    //     expect(pendingRewardBob).to.gt(0)
    // })

    // it("Two deposits (- amount) ", async () => {
    //     // await rewardToken.transfer(chef.address, ether(100000000))
    //     await rewardToken.approve(chef.address, ether(100000000))
    //     await chef.depositReward(POOL_ID, ether(100000000))

    //     await stakeToken.transfer(alice.address, ether(1000))
    //     await stakeToken.connect(alice).approve(chef.address, ether(1000))
    //     await chef.connect(alice).deposit(POOL_ID, ether(1000))

    //     await stakeToken.transfer(bob.address, ether(4000))
    //     await stakeToken.connect(bob).approve(chef.address, ether(4000))

    //     const blockNumber = await ethers.provider.getBlockNumber()
    //     const block = await ethers.provider.getBlock(blockNumber)
    //     const startTime = block.timestamp
    //     const endTime = block.timestamp + 3600 * 24 * 100
    //     await chef.updatePool(POOL_ID, REWARD_UNIT, 10000, startTime, endTime)

    //     await mineTime(3600)
    //     console.info(`bob adds 2000`)
    //     await chef.connect(bob).deposit(POOL_ID, ether(2000))

    //     let pendingRewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (alice, begin): ${toEther(pendingRewardAlice)}`)
    //     let pendingRewardBob = await chef.pendingReward(POOL_ID, bob.address)
    //     console.info(`pendingReward (bob, begin): ${toEther(pendingRewardBob)}`)

    //     await mineTime(3600)
    //     pendingRewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (alice, after 1h): ${toEther(pendingRewardAlice)}`)
    //     pendingRewardBob = await chef.pendingReward(POOL_ID, bob.address)
    //     console.info(`pendingReward (bob, after 1h): ${toEther(pendingRewardBob)}`)

    //     console.info(`bob removes 1000`)
    //     await chef.connect(bob).withdraw(POOL_ID, ether(1000))
    //     const balOfBob = await stakeToken.balanceOf(bob.address)
    //     expect(balOfBob).to.eq(ether(2000 + 1000 * 0.97)) //3%

    //     pendingRewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (alice, after 1h): ${toEther(pendingRewardAlice)}`)
    //     pendingRewardBob = await chef.pendingReward(POOL_ID, bob.address)
    //     console.info(`pendingReward (bob, after 1h): ${toEther(pendingRewardBob)}`)

    //     await mineTime(3600)
    //     pendingRewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (alice, after 2h): ${toEther(pendingRewardAlice)}`)
    //     pendingRewardBob = await chef.pendingReward(POOL_ID, bob.address)
    //     console.info(`pendingReward (bob, after 2h): ${toEther(pendingRewardBob)}`)

    //     await mineTime(3600)
    //     pendingRewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (alice, after 3h): ${toEther(pendingRewardAlice)}`)
    //     pendingRewardBob = await chef.pendingReward(POOL_ID, bob.address)
    //     console.info(`pendingReward (bob, after 3h): ${toEther(pendingRewardBob)}`)

    //     await mineTime(3600 * 7)
    //     pendingRewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (alice, after 10h): ${toEther(pendingRewardAlice)}`)
    //     pendingRewardBob = await chef.pendingReward(POOL_ID, bob.address)
    //     console.info(`pendingReward (bob, after 10h): ${toEther(pendingRewardBob)}`)

    //     await mineTime(3600 * 24 * 29)
    //     pendingRewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (alice, after 30d): ${toEther(pendingRewardAlice)}`)
    //     pendingRewardBob = await chef.pendingReward(POOL_ID, bob.address)
    //     console.info(`pendingReward (bob, after 30d): ${toEther(pendingRewardBob)}`)

    //     expect(pendingRewardAlice).to.gt(0)
    //     expect(pendingRewardBob).to.gt(0)

    //     await chef.connect(alice).withdraw(POOL_ID, ether(1000))
    //     await chef.connect(bob).withdraw(POOL_ID, ether(1000))

    //     console.info(`[after 3 days] bob removes 1000`)
    //     const newbalOfBob = await stakeToken.balanceOf(bob.address)
    //     expect(newbalOfBob).to.eq(ether(2000 + 1000 * 0.97 + 1000)) //3%
    //     await expect(chef.connect(bob).withdraw(POOL_ID, ether(1000))).to.be.reverted

    //     pendingRewardAlice = await chef.pendingReward(POOL_ID, alice.address)
    //     console.info(`pendingReward (alice, after 30d): ${toEther(pendingRewardAlice)}`)
    //     pendingRewardBob = await chef.pendingReward(POOL_ID, bob.address)
    //     console.info(`pendingReward (bob, after 30d): ${toEther(pendingRewardBob)}`)

    //     const rewardAlice = await rewardToken.balanceOf(alice.address)
    //     console.info(`reward (alice): ${toEther(rewardAlice)}`)
    //     const rewardBob = await rewardToken.balanceOf(bob.address)
    //     console.info(`reward (bob): ${toEther(rewardBob)}`)
    //     expect(rewardAlice).to.gt(0)
    //     expect(rewardBob).to.gt(0)
    // })
})
