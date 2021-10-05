import chai, { expect } from "chai"
import { BigNumber, Contract } from "ethers"
import { ether, toEther, parseUnits, mineTime } from "./shared/util"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { network, ethers } from "hardhat"

describe("GameFi", () => {
    let owner: SignerWithAddress
    let alice: SignerWithAddress
    let bob: SignerWithAddress

    let gameToken: Contract
    let rewardToken: Contract
    let nft: Contract
    let gameManager: Contract
    let gameFi: Contract

    const FEE_LAY_EGG = ether(100)
    const FEE_CHANGE_TRIBE = ether(1)
    const FEE_UPGRADE_GENERATION = ether(5)

    beforeEach(async () => {
        ;[owner, alice, bob] = await ethers.getSigners()
        const ERC20Token = await ethers.getContractFactory("ERC20Token")
        const NFT = await ethers.getContractFactory("NFT")
        const GameManager = await ethers.getContractFactory("GameManager")
        const GameFi = await ethers.getContractFactory("GameFi")
        gameToken = await ERC20Token.deploy()
        rewardToken = await ERC20Token.deploy()

        // manager
        gameManager = await GameManager.deploy()
        await gameManager.setPropsU256("feeLayEgg", FEE_LAY_EGG)
        await gameManager.setPropsU256("feeChangeTribe", FEE_CHANGE_TRIBE)
        await gameManager.setPropsU256("feeUpgradeGeneration", FEE_UPGRADE_GENERATION)

        // nft
        nft = await NFT.deploy("Space Man", "SPACEMAN", gameManager.address, gameToken.address)

        // gamefi
        gameFi = await GameFi.deploy(nft.address, gameToken.address, rewardToken.address)
        gameManager.addRole("EVOLVER", gameFi.address)
        expect(await gameManager.isRole("EVOLVER", gameFi.address), "gamefi role: EVOLVER").to.eq(true)

        await gameToken.transfer(alice.address, ether(10000))
        await rewardToken.transfer(gameFi.address, ether(1000000))
        console.info(`gamefi lanched.`)

        // alice: approve transferring to GameFi 
        await gameToken.connect(alice).approve(gameFi.address, '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff')
    })

    it("Lay Eggs", async () => {
        await gameFi.connect(alice).layEgg([0])

        expect(await gameToken.balanceOf(alice.address), "alice balance").to.eq(ether(10000).sub(FEE_LAY_EGG))
        await expect(gameFi.connect(bob).layEgg([0]), "bob has no fund").to.be.reverted
    })
})
