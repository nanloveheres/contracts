import { BigNumber, utils, BigNumberish } from 'ethers'

export function ether(n: string | number): BigNumber {
    return utils.parseEther(n.toString())
    // return BigNumber.from(n).mul(BigNumber.from(10).pow(18))
}

export function toEther(n: BigNumberish): string {
    return utils.formatEther(n)
}

export function parseUnits(value: string | number, unitName?: BigNumberish): BigNumber {
    return utils.parseUnits(value.toString(), unitName)
}

export default utils