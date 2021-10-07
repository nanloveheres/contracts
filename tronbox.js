/*
Create a .env file (it must be gitignored) containing something like

  export PRIVATE_KEY_MAINNET=xxx

Then, run the migration with:

  source .env && tronbox migrate --network shasta
  source .env && tronbox migrate --network mainnet

*/
require("dotenv").config()
require("ts-node").register({
  files: true,
})

module.exports = {
    networks: {
        mainnet: {
            // Don't put your private key here:
            privateKey: process.env.PRIVATE_KEY_MAINNET,
            userFeePercentage: 100,
            feeLimit: 1000 * 1e6,
            fullHost: "https://api.trongrid.io",
            network_id: "1"
        },
        shasta: {
            privateKey: process.env.PRIVATE_KEY_SHASTA,
            userFeePercentage: 50,
            feeLimit: 1000 * 1e6,
            fullHost: "https://api.shasta.trongrid.io",
            network_id: "2"
        },
        development: {
            // For trontools/quickstart docker image
            privateKey: "da146374a75310b9666e834ee4ad0866d6f4035967bfc76217c5a495fff9f0d0",
            userFeePercentage: 0,
            feeLimit: 1000 * 1e6,
            fullHost: "http://127.0.0.1:" + (process.env.HOST_PORT || 9090),
            network_id: "9"
        },
        compilers: {
            solc: {
                version: "0.8.6"
            }
        }
    },
    // solc compiler optimize
    solc: {
        optimizer: {
            enabled: true,
            runs: 200
        }
        //   evmVersion: 'istanbul'
    }
}
