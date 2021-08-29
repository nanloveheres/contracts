import chai, { expect } from 'chai'
import { BigNumber, Contract, utils } from 'ethers'
import { solidity, MockProvider, deployContract } from 'ethereum-waffle'
import AdminRole from '../build/ExampleAdminRole.json'
import { ether, toEther } from './shared/util'

chai.use(solidity)

const overrides = {
    gasLimit: 9999999,
    gasPrice: 0
}

describe('AdminRole', () => {
    const provider = new MockProvider({
        ganacheOptions: {
            gasLimit: 9999999
        }
    })
    const [walletDeployer, walletAlice, walletBob] = provider.getWallets()

    let contract: Contract

    beforeEach(async () => {
        contract = await deployContract(walletDeployer, AdminRole, [walletAlice.address], overrides)
        console.info(`contract: ${contract.address}`)
    })

    it('is admin', async () => {
        console.info(walletAlice.address)
        expect(await contract.isAdmin(walletDeployer.address), 'deploy').eq(true)
        expect(await contract.isAdmin(walletAlice.address), 'alice admin').eq(false)
        expect(await contract.isAdmin(walletBob.address), 'bob').eq(false)
        expect(await contract.hasRole(await contract.SUPER_ROLE(), walletAlice.address), 'alice super').eq(true)
    })

    it('destruct', async () => {
        console.info(`send ether...`)
        await walletDeployer.sendTransaction({ to: contract.address, value: ether(1), gasLimit: 9999999 })
        console.info(`check ether...`)
        expect(await provider.getBalance(contract.address)).to.be.eq(ether(1))

        const balanceAlice = await walletAlice.getBalance()
        console.info(`bal (Alice): ${toEther(balanceAlice)}`)
        console.info(`destructing...`)
        await contract.connect(walletAlice).close()
        const newBalanceAlice = await walletAlice.getBalance()
        console.info(`new bal (Alice): ${toEther(newBalanceAlice)}`)
        expect(newBalanceAlice.sub(balanceAlice)).to.be.closeTo(ether(1), 99900000000000)
    })
})
