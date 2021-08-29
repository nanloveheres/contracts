import '@nomiclabs/hardhat-waffle'
import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-etherscan'
import '@openzeppelin/hardhat-upgrades'
// import 'hardhat-deploy'
// import 'hardhat-gas-reporter'
// import 'hardhat-docgen'
// import '@typechain/hardhat'
import dotenv from 'dotenv'
dotenv.config()

// https://hardhat.org/guides/create-task.html
// task('accounts', 'Prints the list of accounts', async () => {
//     const accounts = await ethers.getSigners()

//     for (const account of accounts) {
//         console.info(account.address)
//     }
// })

// Go to https://hardhat.org/config/ to learn more

// console.info('env: ', process.env)
const { PRIVATE_KEY, ETHERSCAN_API_KEY } = process.env
const MNEMONIC = process.env.MNEMONIC || 'test test test test test test test test test test test junk'
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    solidity: {
        version: '0.8.7',
        settings: {
            optimizer: {
                enabled: true,
                runs: 200
            }
        }
    },
    defaultNetwork: 'hardhat',
    networks: {
        hardhat: {
            accounts: {
                MNEMONIC,
                accountsBalance: '100000000000000000000000000'
            },
            blockGasLimit: 60000000
        },
        localhost: {
            url: 'http://localhost:8545/',
            chainId: 31337,
            accounts: [`0x${PRIVATE_KEY}`]
        },
        bsc: {
            url: 'https://bsc-dataseed.binance.org/',
            chainId: 56,
            gasPrice: 1000000000,
            accounts: [`0x${PRIVATE_KEY}`]
        },
        bsctest: {
            url: `https://data-seed-prebsc-1-s1.binance.org:8545`,
            chainId: 97,
            gasPrice: 1000000000,
            accounts: [`0x${PRIVATE_KEY}`]
        },
        ropsten: {
            url: `https://eth-ropsten.alchemyapi.io/v2/SxR_h_dE4t13Tw_mieLOZz4PfJ2-xyll`,
            chainId: 3,
            accounts: [`0x${PRIVATE_KEY}`]
        },
        heco: {
            url: 'https://http-mainnet-node.huobichain.com',
            chainId: 128,
            accounts: [`0x${PRIVATE_KEY}`]
        }
    },
    etherscan: {
        apiKey: ETHERSCAN_API_KEY
    },
    paths: {
        sources: './contracts',
        tests: './test',
        cache: './cache',
        artifacts: './artifacts'
    },
    mocha: {
        timeout: 20000
    }
}
