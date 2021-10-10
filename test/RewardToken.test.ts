import chai, { expect } from "chai"
import { beforeEach } from "mocha"
import { Contract } from "ethers"
import { ether } from "./shared/util"
import { network, ethers } from "hardhat"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"

describe("RewardToken", () => {
    let owner: SignerWithAddress
    let alice: SignerWithAddress
    let bob: SignerWithAddress

    let token: Contract

    beforeEach(async () => {
        const RewardToken = await ethers.getContractFactory("RewardToken")
        ;[owner, alice, bob] = await ethers.getSigners()

        token = await RewardToken.deploy()
        await token.deployed()
        await token.connect(owner).transfer(alice.address, ether(1000))

        const blockNumber = await ethers.provider.getBlockNumber()
        const block = await ethers.provider.getBlock(blockNumber)
        const startTime = block.timestamp + 24 * 60 * 60 * 7
        console.info(`startTime: ${startTime}`)
    })

    it("Check token balance", async () => {
        expect(await token.balanceOf(alice.address)).to.eq(ether(1000))
    })

    it("Check token symbol", async () => {
        expect(await token.symbol()).to.eq("DPN")
    })

    it("Check token name", async () => {
        expect(await token.name()).to.eq("Daphne Finance")
    })

    it("Transfer adds amount to destination account", async () => {
        await token.connect(alice).transfer(bob.address, ether(10))
        expect(await token.balanceOf(bob.address)).to.eq(ether(10))
    })

    it("Transfer emits event", async () => {
        await expect(token.connect(alice).transfer(bob.address, 100)).to.emit(token, "Transfer").withArgs(alice.address, bob.address, 100)
    })

    it("Can not transfer above the amount", async () => {
        await expect(token.connect(alice).transfer(bob.address, ether(1001))).to.be.reverted
    })

    it("Can not transfer from empty account", async () => {
        await expect(token.connect(bob).transfer(alice.address, 1)).to.be.reverted
    })

    it("Calls totalSupply on Token contract", async () => {
        const totalSupply = await token.totalSupply()
        expect(totalSupply).to.be.equal(ether(1).mul(10 ** 8))
    })

    it("anti whale", async () => {
        await token.setAntiWhale(true)
        await token.setWhale(bob.address, true)
        await expect(token.connect(alice).transfer(bob.address, 1)).to.be.reverted
        await token.setWhale(bob.address, false)
        await token.connect(alice).transfer(bob.address, ether(1))
        expect(await token.balanceOf(alice.address), "alice").to.eq(ether(999))
        expect(await token.balanceOf(bob.address), "bob").to.eq(ether(1))
    })
})
