import {Wallet} from "ethers"
import crypto from "crypto"

async function main(): Promise<void> {
    const count = 10000000
    let i = 0
    console.log("generate a new address...")
    while (i++ < count) {
        const id = crypto.randomBytes(32).toString("hex")
        const privateKey = "0x" + id

        const wallet = new Wallet(privateKey)
        if (isFavorite(wallet.address)) {
            console.log("key:", privateKey)
            console.log("address: ", wallet.address)
            break
        }
        if (i % 1000 == 0) {
            console.log(i)
        }
    }
}

const isFavorite = (address: string): boolean => {
    return address.endsWith("888888")
}

main()
    .then(() => process.exit(0))
    .catch((error: Error) => {
        console.error(error)
        process.exit(1)
    })
