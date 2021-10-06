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

    const FEE_LAY_EGG = ether(100)
    const FEE_CHANGE_TRIBE = ether(1)
    const FEE_UPGRADE_GENERATION = ether(5)

    beforeEach(async () => {
        ;[owner, alice, bob, market] = await ethers.getSigners()
        const PseudoRandom = await ethers.getContractFactory("PseudoRandom")
        const ERC20Token = await ethers.getContractFactory("ERC20Token")
        const NFT = await ethers.getContractFactory("NFT")
        const GameManager = await ethers.getContractFactory("GameManager")
        const GameFight = await ethers.getContractFactory("GameFight")
        const GameFi = await ethers.getContractFactory("GameFi")

        const rand = await PseudoRandom.deploy()
        gameToken = await ERC20Token.deploy()
        rewardToken = await ERC20Token.deploy()

        // manager
        gameManager = await GameManager.deploy()
        await gameManager.setPropsU256("feeLayEgg", FEE_LAY_EGG)
        await gameManager.setPropsU256("feeChangeTribe", FEE_CHANGE_TRIBE)
        await gameManager.setPropsU256("feeUpgradeGeneration", FEE_UPGRADE_GENERATION)
        await gameManager.setFeeAddress(market.address)

        // nft
        nft = await NFT.deploy("Space Man", "SPACEMAN", gameManager.address)

        // fight
        gameFight = await GameFight.deploy(nft.address, gameManager.address, rand.address)

        // gamefi
        gameFi = await GameFi.deploy(nft.address, gameToken.address, rewardToken.address, gameManager.address, gameFight.address, rand.address)
        gameManager.addRole("SPAWN", gameFi.address)
        gameManager.addRole("BATTLE", gameFi.address)
        expect(await gameManager.isRole("SPAWN", gameFi.address), "gamefi role: SPAWN").to.eq(true)

        await gameToken.transfer(alice.address, ether(10000))
        await rewardToken.transfer(gameFi.address, ether(1000000))
        console.info(`GameFi lanched.`)

        // alice: approve transferring to GameFi
        await gameToken.connect(alice).approve(gameFi.address, "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")
    })

    it("Lay one egg", async () => {
        await gameFi.connect(alice).layEgg([0])
        expect(await gameToken.balanceOf(alice.address), "alice balance").to.eq(ether(10000).sub(FEE_LAY_EGG))
        await expect(gameFi.connect(bob).layEgg([0]), "bob has no fund").to.be.reverted
    })

    it("Lay multi eggs", async () => {
        await gameFi.connect(alice).layEgg([0, 0, 1, 2, 3])
        expect(await gameToken.balanceOf(alice.address), "alice balance").to.eq(ether(10000).sub(FEE_LAY_EGG.mul(5)))
    })

    it("Hatch", async () => {
        await gameFi.connect(alice).layEgg([0])
        await gameFi.connect(alice).hatch(1)
    })

    it("Fight monster", async () => {
        await gameFi.connect(alice).layEgg([0])
        await gameFi.connect(alice).hatch(1)
        await gameFi.connect(alice).fightMonster(1, 0)   
        expect(await rewardToken.balanceOf(alice.address), "alice balance").to.gt(0)     
    })

    it("Emergency withdraw", async () => {
        expect(await gameToken.balanceOf(market.address), "market balance").to.eq(0)
        await gameFi.connect(alice).layEgg([0])
        expect(await gameToken.balanceOf(alice.address), "alice balance").to.eq(ether(10000).sub(FEE_LAY_EGG))
        await gameFi.emergencyWithdraw()
        expect(await gameToken.balanceOf(market.address), "market balance").to.eq(FEE_LAY_EGG)
    })
})
