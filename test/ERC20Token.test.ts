import chai, { expect } from 'chai'
import { beforeEach } from 'mocha'
import { Contract } from 'ethers'
// import { solidity, MockProvider, deployContract } from 'ethereum-waffle'
import { ether } from './shared/util'
import { network, ethers } from 'hardhat'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { solidity } from 'ethereum-waffle'
chai.use(solidity)

let owner: SignerWithAddress
let alice: SignerWithAddress
let bob: SignerWithAddress

let token: Contract

beforeEach(async () => {
    const ERC20Token = await ethers.getContractFactory('ERC20Token')
    ;[owner, alice, bob] = await ethers.getSigners()

    token = await ERC20Token.deploy()
    await token.deployed()
    await token.deployed()
    await token.connect(owner).transfer(alice.address, ether(1000))
})


describe('ERC20Token', () => {
    it('Check token balance', async () => {
        expect(await token.balanceOf(alice.address)).to.eq(ether(1000))
    })

    it('Check token symbol', async () => {
        expect(await token.symbol()).to.eq('CHIS')
    })

    it('Check token name', async () => {
        expect(await token.name()).to.eq('Chis Finance')
    })

    it('Transfer adds amount to destination account', async () => {
        await token.connect(alice).transfer(bob.address, ether(10))
        expect(await token.balanceOf(bob.address)).to.eq(ether(10))
    })

    it('Transfer emits event', async () => {
        await expect(token.connect(alice).transfer(bob.address, 100))
            .to.emit(token, 'Transfer')
            .withArgs(alice.address, bob.address, 100)
    })

    it('Can not transfer above the amount', async () => {
        await expect(token.connect(alice).transfer(bob.address, ether(1001))).to.be.reverted
    })

    it('Can not transfer from empty account', async () => {
        await expect(token.connect(bob).transfer(alice.address, 1)).to.be.reverted
    })

    it('Calls totalSupply on Token contract', async () => {
        const totalSupply = await token.totalSupply()
        expect(totalSupply).to.be.equal(ether(1).mul(ether(1)))
    })
})
