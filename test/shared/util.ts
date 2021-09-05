import { BigNumber, utils, BigNumberish } from "ethers"
import { network, ethers } from "hardhat"

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

export async function mineTime(time: number) {
    await network.provider.send("evm_increaseTime", [time])
    await network.provider.send("evm_mine")
}
// export default utils
