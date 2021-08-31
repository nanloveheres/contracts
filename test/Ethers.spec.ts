import chai, { expect } from 'chai'
import { BigNumber, utils } from 'ethers'

describe('Ethers', () => {
    beforeEach(async () => {})

    it('encode function', async () => {
        const abi = ['function registerVIP(address, uint, address)']
        const iface = new utils.Interface(abi)
        const funcHash = iface.encodeFunctionData('registerVIP', [
            '0x1234567890123456789012345678901234567890',
            BigNumber.from('1'),
            '0x1234567890123456789012345678901234567890'
        ])

        expect(funcHash.indexOf('0x118e98c')).to.eq(0)
    })

    it('func getVIPInfo', async () => {
        const abi = ['function getVIPInfo(address)']
        const iface = new utils.Interface(abi)
        const funcHash = iface.encodeFunctionData('getVIPInfo', ['0x1234567890123456789012345678901234567890'])

        // console.info(funcHash)
        expect(funcHash.indexOf('0xe83c4148')).to.eq(0)
    })
})
