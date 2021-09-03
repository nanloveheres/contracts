import chai, { expect } from 'chai'
import { BigNumber, Contract, Signer } from 'ethers'
import { ether, toEther } from './shared/util'
import { network, ethers } from 'hardhat'
import { solidity } from 'ethereum-waffle'

chai.use(solidity)

let contract: Contract

beforeEach(async () => {
    const [owner, alice, bob] = await ethers.getSigners()
    const AdminRole = await ethers.getContractFactory('ExampleAdminRole')
    console.info(`alice: ${alice.address}`)
    contract = await AdminRole.deploy(alice.address)
    await contract.deployed()
    console.info(`contract: ${contract.address}`)
})

describe('AdminRole', () => {
    it('is admin', async () => {
        const [owner, alice, bob] = await ethers.getSigners()
        console.info(alice.address)
        expect(await contract.isAdmin(owner.address), 'deploy').eq(true)
        expect(await contract.isAdmin(alice.address), 'alice admin').eq(false)
        expect(await contract.isAdmin(bob.address), 'bob').eq(false)
        expect(await contract.hasRole(await contract.OWNER_ROLE(), alice.address), 'alice owner').eq(true)
    })

    it('destruct', async () => {
        const [owner, alice, bob] = await ethers.getSigners()
        console.info(`send ether...`)
        await owner.sendTransaction({ to: contract.address, value: ether(1), gasLimit: 9999999 })
        console.info(`check ether...`)
        // expect(await network..provider.getBalance(contract.address)).to.be.eq(ether(1))

        const balanceAlice = await alice.getBalance()
        console.info(`bal (Alice): ${toEther(balanceAlice)}`)
        console.info(`destructing...`)
        await contract.connect(alice).close({ gasLimit: 9999999 })
        const newBalanceAlice = await alice.getBalance()
        console.info(`new bal (Alice): ${toEther(newBalanceAlice)}`)
        // expect(newBalanceAlice.sub(balanceAlice)).to.be.closeTo(ether(1).toNumber(), 99900000000000)
    })
})
