import { task } from "hardhat/config"
import fs from "fs"
import { config as dotenvConfig } from "dotenv"
import { resolve } from "path"
import { utils } from "ethers"
dotenvConfig({ path: resolve(__dirname, "./.env") })

import { HardhatUserConfig } from "hardhat/types"
import { NetworkUserConfig } from "hardhat/types"

import "@nomiclabs/hardhat-waffle"
import "@nomiclabs/hardhat-ethers"

import "hardhat-gas-reporter"
import "@nomiclabs/hardhat-etherscan"

const chainIds = {
    ganache: 1337,
    goerli: 5,
    hardhat: 31337,
    kovan: 42,
    mainnet: 1,
    rinkeby: 4,
    ropsten: 3
}

const PRIVATE_KEY = process.env.PRIVATE_KEY || ""
const MNEMONIC = process.env.MNEMONIC || "test test test test test test test test test test test test"
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || ""
const INFURA_API_KEY = process.env.INFURA_API_KEY || ""
const ALCHEMY_KEY = process.env.ALCHEMY_KEY || ""

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (args, hre) => {
    const accounts = await hre.ethers.getSigners()

    for (const account of accounts) {
        console.log(await account.getAddress())
    }
})

task("verify:code", "Verify contract code", async (args, hre) => {
    const encodedArgs = `0x${fs.readFileSync("artifacts/MasterChef.args")}`
    const constructorArguments = utils.defaultAbiCoder.decode(["address", "uint256", "uint256"], encodedArgs)
    await hre.run("verify:verify", {
        address: fs.readFileSync("artifacts/MasterChef.address").toString(),
        constructorArguments
    })
})

function createTestnetConfig(network: keyof typeof chainIds): NetworkUserConfig {
    const url = `https://eth-${network}.alchemyapi.io/v2/${ALCHEMY_KEY}`
    return {
        accounts: [`0x${PRIVATE_KEY}`],
        chainId: chainIds[network],
        url
    }
}

function createTestnetConfigMnemonic(network: keyof typeof chainIds): NetworkUserConfig {
    const url: string = "https://" + network + ".infura.io/v3/" + INFURA_API_KEY
    return {
        accounts: {
            count: 10,
            initialIndex: 0,
            mnemonic: MNEMONIC,
            path: "m/44'/60'/0'/0"
        },
        chainId: chainIds[network],
        url
    }
}

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
    defaultNetwork: "hardhat",
    networks: {
        hardhat: {
            accounts: {
                mnemonic: MNEMONIC
            },
            blockGasLimit: 60000000,
            chainId: chainIds.hardhat
        },
        mainnet: createTestnetConfig("mainnet"),
        goerli: createTestnetConfig("goerli"),
        kovan: createTestnetConfig("kovan"),
        rinkeby: createTestnetConfig("rinkeby"),
        ropsten: createTestnetConfig("ropsten"),
        localhost: {
            url: "http://localhost:8545/",
            chainId: 31337,
            accounts: [`0x${PRIVATE_KEY}`]
        },
        bsc: {
            url: "https://bsc-dataseed.binance.org/",
            chainId: 56,
            gas: 2100000,
            gasPrice: 10000000000,
            accounts: [`0x${PRIVATE_KEY}`]
        },
        bsctest: {
            url: `https://data-seed-prebsc-1-s1.binance.org:8545`,
            chainId: 97,
            gas: 2100000,
            gasPrice: 10000000000,
            accounts: [`0x${PRIVATE_KEY}`]
        },
        heco: {
            url: "https://http-mainnet-node.huobichain.com",
            chainId: 128,
            accounts: [`0x${PRIVATE_KEY}`]
        }
    },
    solidity: {
        version: "0.8.4",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200
            }
        }
    },
    mocha: {
        timeout: 20000
    },
    etherscan: {
        apiKey: ETHERSCAN_API_KEY
    },
    gasReporter: {
        currency: "USD",
        gasPrice: 100
        // enabled: process.env.REPORT_GAS ? true : false,
    }
}

export default config
