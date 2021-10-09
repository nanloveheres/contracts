import chai, { expect } from "chai"
import { BigNumber, Contract } from "ethers"
import { ether, toEther, parseUnits, mineTime } from "./shared/util"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { network, ethers } from "hardhat"

describe("GameFi", () => {
    let owner: SignerWithAddress
    let alice: SignerWithAddress
    let bob: SignerWithAddress
    let market: SignerWithAddress

    let gameToken: Contract
    let rewardToken: Contract
    let nft: Contract
    let gameManager: Contract
    let gameFight: Contract
    let gameFi: Contract
    let mockRandom: Contract

    const FEE_LAY_EGG = ether(100)
    const FEE_CHANGE_TRIBE = ether(1)
    const FEE_UPGRADE_GENERATION = ether(5)
    const EMPTY_REFERRAL = "0x0000000000000000000000000000000000000000"
    const MAX_AMOUNT = "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"

    beforeEach(async () => {
        ;[owner, alice, bob, market] = await ethers.getSigners()
        const PseudoRandom = await ethers.getContractFactory("PseudoRandom")
        const MockRandom = await ethers.getContractFactory("MockRandom")
        const ERC20Token = await ethers.getContractFactory("ERC20Token")
        const RewardToken = await ethers.getContractFactory("RewardToken")
        const NFT = await ethers.getContractFactory("NFT")
        const GameManager = await ethers.getContractFactory("GameManager")
        const GameFight = await ethers.getContractFactory("GameFight")
        const GameFi = await ethers.getContractFactory("GameFi")

        // const rand = await PseudoRandom.deploy()
        mockRandom = await MockRandom.deploy()
        gameToken = await ERC20Token.deploy()
        rewardToken = await RewardToken.deploy()

        // manager
        gameManager = await GameManager.deploy()
        await gameManager.setPropsU256("feeLayEgg", FEE_LAY_EGG)
        await gameManager.setPropsU256("feeChangeTribe", FEE_CHANGE_TRIBE)
        await gameManager.setPropsU256("feeUpgradeGeneration", FEE_UPGRADE_GENERATION)
        await gameManager.setFeeAddress(market.address)

        // nft
        nft = await NFT.deploy("Space Man", "SPACEMAN", gameManager.address)

        // fight
        gameFight = await GameFight.deploy(nft.address, gameManager.address, mockRandom.address)

        // gamefi
        gameFi = await GameFi.deploy(nft.address, gameToken.address, rewardToken.address, gameManager.address, gameFight.address, mockRandom.address)
        gameManager.addRole("SPAWN", gameFi.address)
        gameManager.addRole("BATTLE", gameFi.address)
        expect(await gameManager.isRole("SPAWN", gameFi.address), "gamefi role: SPAWN").to.eq(true)

        await gameToken.transfer(alice.address, ether(10000))
        await rewardToken.transfer(gameFi.address, ether(10000000))
        console.info(`GameFi lanched.`)

        // alice: approve transferring to GameFi
        await gameToken.connect(alice).approve(gameFi.address, MAX_AMOUNT)
    })

    it("Lay one egg", async () => {
        await gameFi.connect(alice).layEgg([0], EMPTY_REFERRAL)
        expect(await gameToken.balanceOf(alice.address), "alice balance").to.eq(ether(10000).sub(FEE_LAY_EGG))
        await expect(gameFi.connect(bob).layEgg([0]), "bob has no fund").to.be.reverted
    })

    it("Lay multi eggs", async () => {
        await gameFi.connect(alice).layEgg([0, 0, 1, 2, 3], EMPTY_REFERRAL)
        expect(await gameToken.balanceOf(alice.address), "alice balance").to.eq(ether(10000).sub(FEE_LAY_EGG.mul(5)))
    })

    it("Hatch", async () => {
        await gameFi.connect(alice).layEgg([0], EMPTY_REFERRAL)
        await mockRandom.setV(1000)
        await gameFi.connect(alice).hatch(1)
        expect(await nft.rare(1)).to.eq(3)
    })

    it("Fight monster", async () => {
        await gameFi.connect(alice).layEgg([0], EMPTY_REFERRAL)
        await mockRandom.setV(1000)
        await gameFi.connect(alice).hatch(1)

        // mock win
        let fightRatio = 1 // within 80
        await mockRandom.setV(fightRatio)
        const exp = 5 + Math.floor((fightRatio * 5) / 80)
        await expect(gameFi.connect(alice).fightMonster(1, 0)).emit(gameFi, "Fight").withArgs(1, exp, ether(exp))
        expect(await rewardToken.balanceOf(alice.address), "alice balance").to.eq(ether(exp))

        // mock lose
        fightRatio = 88 // out of 80
        await mockRandom.setV(fightRatio)
        await expect(gameFi.connect(alice).fightMonster(1, 0)).emit(gameFi, "Fight").withArgs(1, 0, 0)
        expect(await rewardToken.balanceOf(alice.address), "alice balance").to.eq(ether(exp))
    })

    it("Fight monster > remaining fight num", async () => {
        await gameFi.connect(alice).layEgg([0], EMPTY_REFERRAL)
        await mockRandom.setV(1000) // rare = 3
        await gameFi.connect(alice).hatch(1)
        expect(await gameFight.getRemainingFightNum(1), "remaining fight num").to.eq(3)
    })

    it("Fight monster > remaining fight num > diff intervals", async () => {
        await gameFi.connect(alice).layEgg([0], EMPTY_REFERRAL)
        await mockRandom.setV(1000) // rare = 3
        await gameFi.connect(alice).hatch(1)
        expect(await gameFight.getRemainingFightNum(1), "remaining fight num, 1st").to.eq(3)

        const fightTimeInterval = (await gameManager.fightTimeInterval()).toNumber()
        await mineTime(fightTimeInterval)
        expect(await gameFight.getRemainingFightNum(1), "remaining fight num, 2nd").to.eq(6)

        await mineTime(fightTimeInterval)
        expect(await gameFight.getRemainingFightNum(1), "remaining fight num, 3rd").to.eq(6) // max quote = 6
    })

    it("Fight monster in multiple times", async () => {
        await gameFi.connect(alice).layEgg([0], EMPTY_REFERRAL)
        await mockRandom.setV(1000) // rare = 3
        await gameFi.connect(alice).hatch(1)
        expect(await gameFight.getRemainingFightNum(1), "remaining fight num = 3").to.eq(3)

        // mock win
        let fightRatio = 1 // within 80
        await mockRandom.setV(fightRatio)
        let exp = 5 + Math.floor((fightRatio * (15 - 5)) / 80)
        console.info(`exp : ${exp}`)
        let totalExp = exp
        await expect(gameFi.connect(alice).fightMonster(1, 0), "fight").emit(gameFi, "Fight").withArgs(1, exp, ether(exp))
        expect(await rewardToken.balanceOf(alice.address), "alice balance").to.eq(ether(totalExp))
        expect(await gameFight.getRemainingFightNum(1), "remaining fight num = 2").to.eq(2)

        // mock lose
        fightRatio = 88 // out of 80
        await mockRandom.setV(fightRatio)
        exp = 0
        await expect(gameFi.connect(alice).fightMonster(1, 0), "fight").emit(gameFi, "Fight").withArgs(1, exp, ether(exp))
        expect(await rewardToken.balanceOf(alice.address), "alice balance").to.eq(ether(totalExp))
        expect(await gameFight.getRemainingFightNum(1), "remaining fight num = 1").to.eq(1)

        // mock win
        fightRatio = 60 // within 80
        await mockRandom.setV(fightRatio)
        exp = 5 + Math.floor((fightRatio * (15 - 5)) / 80)
        totalExp += exp
        await expect(gameFi.connect(alice).fightMonster(1, 0), "fight").emit(gameFi, "Fight").withArgs(1, exp, ether(exp))
        expect(await rewardToken.balanceOf(alice.address), "alice balance").to.eq(ether(totalExp))
        expect(await gameFight.getRemainingFightNum(1), "remaining fight num = 0").to.eq(0)

        // run out the number of fight quote
        await expect(gameFi.connect(alice).fightMonster(1, 0)).to.be.reverted
    })

    it("Fight monster in max times", async () => {
        await gameFi.connect(alice).layEgg([0], EMPTY_REFERRAL)
        await mockRandom.setV(1000) // rare = 3
        await gameFi.connect(alice).hatch(1)
        expect(await gameFight.getRemainingFightNum(1), "remaining fight num = 3").to.eq(3)
        const fightTimeInterval = (await gameManager.fightTimeInterval()).toNumber()
        await mineTime(fightTimeInterval)
        expect(await gameFight.getRemainingFightNum(1), "remaining fight num = 6").to.eq(6)

        let i = 0
        let totalExp = 0
        while (i++ < 6) {
            // mock win
            const fightRatio = i // within 80
            await mockRandom.setV(fightRatio)
            const exp = 5 + Math.floor((fightRatio * (15 - 5)) / 80)
            totalExp += exp
            await expect(gameFi.connect(alice).fightMonster(1, 0), "fight " + i)
                .emit(gameFi, "Fight")
                .withArgs(1, exp, ether(exp))
            expect(await rewardToken.balanceOf(alice.address), "alice balance").to.eq(ether(totalExp))
            expect(await gameFight.getRemainingFightNum(1), "remaining fight num = 2").to.eq(6 - i)
        }

        // run out the number of fight quote
        await expect(gameFi.connect(alice).fightMonster(1, 0)).to.be.reverted
    })

    it("Has referral", async () => {
        expect(await gameToken.balanceOf(market.address), "market balance").to.eq(0)
        await gameFi.connect(alice).layEgg([0], bob.address)
        expect(await gameToken.balanceOf(alice.address), "alice balance").to.eq(ether(10000).sub(FEE_LAY_EGG))
        expect(await gameToken.balanceOf(bob.address), "bob balance").to.eq(FEE_LAY_EGG.mul(10).div(100))
        expect(await gameToken.balanceOf(market.address), "market balance").to.eq(FEE_LAY_EGG.mul(20).div(100))
    })

    it("No referral", async () => {
        expect(await gameToken.balanceOf(market.address), "market balance").to.eq(0)
        await gameFi.connect(alice).layEgg([0], EMPTY_REFERRAL)
        expect(await gameToken.balanceOf(alice.address), "alice balance").to.eq(ether(10000).sub(FEE_LAY_EGG))
        expect(await gameToken.balanceOf(market.address), "market balance").to.eq(FEE_LAY_EGG.mul(30).div(100))
    })

    it("Emergency withdraw", async () => {
        expect(await gameToken.balanceOf(gameFi.address), "gameFi balance = 0").to.eq(0)
        await gameToken.connect(alice).transfer(gameFi.address, ether(1))
        expect(await gameToken.balanceOf(gameFi.address), "gameFi balance = 1").to.eq(ether(1))

        const ownerBalance = await gameToken.balanceOf(owner.address)
        expect(await gameToken.balanceOf(market.address), "market balance = 0").to.eq(0)
        await gameFi.emergencyWithdraw()
        expect(await gameToken.balanceOf(owner.address), "owner balance = 1").to.eq(ownerBalance.add(ether(1)))
        expect(await gameToken.balanceOf(gameFi.address), "(after emergencyWithdraw) gameFi balance = 0").to.eq(0)
    })
})
