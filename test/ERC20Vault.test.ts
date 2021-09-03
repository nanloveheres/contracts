import chai, { expect } from 'chai'
import { Contract } from 'ethers'
import { ether, toEther, parseUnits } from './shared/util'
import { network, ethers } from 'hardhat'
import { solidity } from 'ethereum-waffle'
chai.use(solidity)

describe('ERC20Vault', async () => {
    const [owner, alice, bob] = await ethers.getSigners()

    let stakeToken: Contract
    let rewardToken: Contract
    let vault: Contract

    beforeEach(async () => {
        const ERC20Token = await ethers.getContractFactory('ERC20Token')
        const RewardToken = await ethers.getContractFactory('RewardToken')
        const ERC20Vault = await ethers.getContractFactory('ERC20Vault')
        stakeToken = await ERC20Token.deploy()
        rewardToken = await RewardToken.deploy()
        vault = await ERC20Vault.deploy([stakeToken.address, rewardToken.address, ether(1), 1, 1000000000])
    })

    it('Check token balance', async () => {
        await stakeToken.transfer(alice.address, ether(1000))
        expect(await stakeToken.balanceOf(alice.address)).to.eq(ether(1000))
    })
})
