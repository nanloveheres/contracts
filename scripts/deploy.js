/* eslint no-use-before-define: "warn" */
const fs = require('fs')
const chalk = require('chalk')
const { config, ethers, upgrades } = require('hardhat')
const { utils } = require('ethers')
const R = require('ramda')

const main = async () => {
    console.log('\n\n 📡 Deploying...\n')

    await deploy('ERC20', [], true)

    // const exampleToken = await deploy("ExampleToken")
    // const examplePriceOracle = await deploy("ExamplePriceOracle")
    // const smartContractWallet = await deploy("SmartContractWallet",[exampleToken.address,examplePriceOracle.address])

    console.log(' 💾  Artifacts (address, abi, and args) saved to: ', chalk.blue('packages/hardhat/artifacts/'), '\n\n')
}

const deploy = async (contractName, _args, upgradable) => {
    console.log(` 🛰  Deploying: ${contractName}`)

    const contractArgs = _args || []
    const contractArtifacts = await ethers.getContractFactory(contractName)

    let deployed
    if (upgradable) {
        const upgradeableContract = await upgrades.deployProxy(contractArtifacts, contractArgs)
        deployed = await upgradeableContract.deployed()
    } else {
        deployed = await contractArtifacts.deploy(...contractArgs)
    }

    const encoded = abiEncodeArgs(deployed, contractArgs)
    fs.writeFileSync(`artifacts/${contractName}.address`, deployed.address)

    console.log(' 📄', chalk.cyan(contractName), 'deployed to:', chalk.magenta(deployed.address))

    if (!encoded || encoded.length <= 2) return deployed
    fs.writeFileSync(`artifacts/${contractName}.args`, encoded.slice(2))

    return deployed
}

// ------ utils -------

// abi encodes contract arguments
// useful when you want to manually verify the contracts
// for example, on Etherscan
const abiEncodeArgs = (deployed, contractArgs) => {
    // not writing abi encoded args if this does not pass
    if (!contractArgs || !deployed || !R.hasPath(['interface', 'deploy'], deployed)) {
        return ''
    }
    const encoded = utils.defaultAbiCoder.encode(deployed.interface.deploy.inputs, contractArgs)
    return encoded
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error)
        process.exit(1)
    })
