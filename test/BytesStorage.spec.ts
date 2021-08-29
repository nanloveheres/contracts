import chai, { expect } from 'chai'
import { BigNumber, Contract, utils } from 'ethers'
import { solidity, MockProvider, deployContract } from 'ethereum-waffle'
import fs from 'fs'
import BytesStorage from '../build/BytesStorage.json'

chai.use(solidity)

const overrides = {
    gasLimit: 9999999,
    gasPrice: 0
}

describe('BytesStorage', () => {
    const provider = new MockProvider({
        ganacheOptions: {
            gasLimit: 9999999
        }
    })
    const [walletDeployer, walletAlice, walletBob] = provider.getWallets()

    let contract: Contract

    beforeEach(async () => {
        contract = await deployContract(walletDeployer, BytesStorage, [], overrides)
    })

    it('Hash check bytes', async () => {
        // 0x4bf5122f344554c53bde2ebb8cd2b7e3d1600ad631c385a5d7cce23c7785459a
        expect(await contract.hash('0x01')).eq(utils.sha256('0x01'))
    })

    it('Store short bytes', async () => {
        const h = utils.sha256('0x01')
        await expect(contract.connect(walletAlice).store('0x01'))
            .to.emit(contract, 'NewPixelArt')
            .withArgs(0, h)

        expect(await contract.hashCheck(h)).eq(true)
    })

    it('Store long bytes', async () => {
        const hexInput = '0xf00dfeed383Fa3B60f9B4AB7fBf6835d3c26C3765cD2B2e2f00dfeed'
        const h = utils.sha256(hexInput)
        await expect(contract.connect(walletAlice).store(hexInput))
            .to.emit(contract, 'NewPixelArt')
            .withArgs(0, h)

        const [data, p] = await contract.query(0)
        expect(data).to.eq(hexInput.toLowerCase())
        expect(p).to.eq(BigNumber.from(h))
    })

    it('Store image', async () => {
        const buf = fs.readFileSync('./test/png/pixel.png')
        const hexInput = `0x${buf.toString('hex')}`
        console.info(hexInput)
        const h = utils.sha256(hexInput)
        await expect(contract.connect(walletAlice).store(hexInput))
            .to.emit(contract, 'NewPixelArt')
            .withArgs(0, h)

        const [data, p] = await contract.query(0)
        expect(data).to.eq(hexInput.toLowerCase())
        expect(p).to.eq(BigNumber.from(h))
    })
})
