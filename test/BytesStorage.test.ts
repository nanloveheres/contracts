import chai, { expect } from 'chai'
import { BigNumber, Contract, utils } from 'ethers'
import { network, ethers } from 'hardhat'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { solidity } from 'ethereum-waffle'

chai.use(solidity)

describe('BytesStorage', () => {
    let contract: Contract

    let owner: SignerWithAddress
    let alice: SignerWithAddress
    let bob: SignerWithAddress

    beforeEach(async () => {
        ;[owner, alice, bob] = await ethers.getSigners()
        const BytesStorage = await ethers.getContractFactory('BytesStorage')

        contract = await BytesStorage.deploy()
        await contract.deployed()
    })

    it('Hash check bytes', async () => {
        // 0x4bf5122f344554c53bde2ebb8cd2b7e3d1600ad631c385a5d7cce23c7785459a
        expect(await contract.hash('0x01')).eq(utils.sha256('0x01'))
    })

    it('Store short bytes', async () => {
        const h = utils.sha256('0x01')
        await expect(contract.connect(alice).store('0x01'))
            .to.emit(contract, 'NewPixelArt')
            .withArgs(0, h)

        expect(await contract.hashCheck(h)).eq(true)
    })
})
