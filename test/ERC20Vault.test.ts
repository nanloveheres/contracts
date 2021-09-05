import chai, { expect } from "chai"
import { Contract } from "ethers"
import { ether, toEther, parseUnits, mineTime } from "./shared/util"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { network, ethers } from "hardhat"

describe("ERC20Vault", () => {
    let owner: SignerWithAddress
    let alice: SignerWithAddress
    let bob: SignerWithAddress

    let stakeToken: Contract
    let rewardToken: Contract
    let vault: Contract

    const POOL_ID = 0

    beforeEach(async () => {
        ;[owner, alice, bob] = await ethers.getSigners()
        const ERC20Token = await ethers.getContractFactory("ERC20Token")
        const RewardToken = await ethers.getContractFactory("RewardToken")
        const ERC20Vault = await ethers.getContractFactory("ERC20Vault")
        stakeToken = await ERC20Token.deploy()
        rewardToken = await RewardToken.deploy()
        vault = await ERC20Vault.deploy()

        const rewardUnit = ether(1)
        const blockNumber = await ethers.provider.getBlockNumber()
        const block = await ethers.provider.getBlock(blockNumber)
        const startTime = block.timestamp
        const endTime = block.timestamp + 3600 * 24 * 100
        const share = 10000

        await vault.setRewardUnit(rewardUnit)
        await vault.newPool(stakeToken.address, rewardToken.address, share, startTime, endTime)
    })

    it("Check stake token balance", async () => {
        await stakeToken.transfer(alice.address, ether(1000))
        expect(await stakeToken.balanceOf(alice.address)).to.eq(ether(1000))
    })

    it("One deposit", async () => {
        await stakeToken.transfer(alice.address, ether(1000))
        await stakeToken.connect(alice).approve(vault.address, ether(1000))
        await vault.connect(alice).deposit(POOL_ID, ether(1000))

        let pendingReward = await vault.pendingReward(POOL_ID, alice.address)
        console.info(`pendingReward (begin): ${toEther(pendingReward)}`)
        await mineTime(3600)
        pendingReward = await vault.pendingReward(POOL_ID, alice.address)
        console.info(`pendingReward (after 1h): ${toEther(pendingReward)}`)
        await mineTime(3600 * 23)
        pendingReward = await vault.pendingReward(POOL_ID, alice.address)
        console.info(`pendingReward (after 24h): ${toEther(pendingReward)}`)
        await mineTime(3600 * 23 * 30)
        pendingReward = await vault.pendingReward(POOL_ID, alice.address)
        console.info(`pendingReward (after 30d): ${toEther(pendingReward)}`)

        expect(pendingReward).to.gt(0)
    })

    it("Two deposits (same time)", async () => {
        await stakeToken.transfer(alice.address, ether(1000))
        await stakeToken.connect(alice).approve(vault.address, ether(1000))
        await vault.connect(alice).deposit(POOL_ID, ether(1000))

        await stakeToken.transfer(bob.address, ether(2000))
        await stakeToken.connect(bob).approve(vault.address, ether(2000))
        await vault.connect(bob).deposit(POOL_ID, ether(2000))

        const blockNumber = await ethers.provider.getBlockNumber()
        const block = await ethers.provider.getBlock(blockNumber)
        const startTime = block.timestamp
        const endTime = block.timestamp + 3600 * 24 * 100
        await vault.updatePool(POOL_ID, 10000, startTime, endTime)

        let pendingRewardAlice = await vault.pendingReward(POOL_ID, alice.address)
        console.info(`pendingReward (alice, begin): ${toEther(pendingRewardAlice)}`)
        let pendingRewardBob = await vault.pendingReward(POOL_ID, bob.address)
        console.info(`pendingReward (bob, begin): ${toEther(pendingRewardBob)}`)

        await mineTime(3600)
        pendingRewardAlice = await vault.pendingReward(POOL_ID, alice.address)
        console.info(`pendingReward (alice, after 1h): ${toEther(pendingRewardAlice)}`)
        pendingRewardBob = await vault.pendingReward(POOL_ID, bob.address)
        console.info(`pendingReward (bob, after 1h): ${toEther(pendingRewardBob)}`)

        await mineTime(3600 * 23)
        pendingRewardAlice = await vault.pendingReward(POOL_ID, alice.address)
        console.info(`pendingReward (alice, after 24h): ${toEther(pendingRewardAlice)}`)
        pendingRewardBob = await vault.pendingReward(POOL_ID, bob.address)
        console.info(`pendingReward (bob, after 24h): ${toEther(pendingRewardBob)}`)

        await mineTime(3600 * 23 * 30)
        pendingRewardAlice = await vault.pendingReward(POOL_ID, alice.address)
        console.info(`pendingReward (alice, after 30d): ${toEther(pendingRewardAlice)}`)
        pendingRewardBob = await vault.pendingReward(POOL_ID, bob.address)
        console.info(`pendingReward (bob, after 30d): ${toEther(pendingRewardBob)}`)

        expect(pendingRewardAlice).to.gt(0)
        expect(pendingRewardBob).to.gt(0)
    })

    it("Two deposits (diff time) ", async () => {
        await stakeToken.transfer(alice.address, ether(1000))
        await stakeToken.connect(alice).approve(vault.address, ether(1000))
        await vault.connect(alice).deposit(POOL_ID, ether(1000))

        await stakeToken.transfer(bob.address, ether(2000))
        await stakeToken.connect(bob).approve(vault.address, ether(2000))

        const blockNumber = await ethers.provider.getBlockNumber()
        const block = await ethers.provider.getBlock(blockNumber)
        const startTime = block.timestamp
        const endTime = block.timestamp + 3600 * 24 * 100
        await vault.updatePool(POOL_ID, 10000, startTime, endTime)

        await mineTime(3600)
        await vault.connect(bob).deposit(POOL_ID, ether(2000))

        let pendingRewardAlice = await vault.pendingReward(POOL_ID, alice.address)
        console.info(`pendingReward (alice, begin): ${toEther(pendingRewardAlice)}`)
        let pendingRewardBob = await vault.pendingReward(POOL_ID, bob.address)
        console.info(`pendingReward (bob, begin): ${toEther(pendingRewardBob)}`)

        await mineTime(3600)
        pendingRewardAlice = await vault.pendingReward(POOL_ID, alice.address)
        console.info(`pendingReward (alice, after 1h): ${toEther(pendingRewardAlice)}`)
        pendingRewardBob = await vault.pendingReward(POOL_ID, bob.address)
        console.info(`pendingReward (bob, after 1h): ${toEther(pendingRewardBob)}`)

        await mineTime(3600 * 23)
        pendingRewardAlice = await vault.pendingReward(POOL_ID, alice.address)
        console.info(`pendingReward (alice, after 24h): ${toEther(pendingRewardAlice)}`)
        pendingRewardBob = await vault.pendingReward(POOL_ID, bob.address)
        console.info(`pendingReward (bob, after 24h): ${toEther(pendingRewardBob)}`)

        await mineTime(3600 * 23 * 30)
        pendingRewardAlice = await vault.pendingReward(POOL_ID, alice.address)
        console.info(`pendingReward (alice, after 30d): ${toEther(pendingRewardAlice)}`)
        pendingRewardBob = await vault.pendingReward(POOL_ID, bob.address)
        console.info(`pendingReward (bob, after 30d): ${toEther(pendingRewardBob)}`)

        expect(pendingRewardAlice).to.gt(0)
        expect(pendingRewardBob).to.gt(0)
    })
})
