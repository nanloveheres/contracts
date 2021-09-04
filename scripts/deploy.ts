// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { ethers } from "hardhat";
import { Contract, ContractFactory, utils } from "ethers";
import fs from "fs";
import chalk from "chalk";

async function main(): Promise<void> {
    await deploy("ERC20Token");
    // const ERC20Token = await ethers.getContractFactory("ERC20Token");
    // const erc20Token = await ERC20Token.deploy();
    // await erc20Token.deployed();
    // console.log("ERC20Token deployed to: ", erc20Token.address);
}

const deploy = async (contractName: string, args?: any[], upgradable?: boolean) => {
    console.log(` 🛰  Deploying: ${contractName}`);

    const contractArgs = args || [];
    const contractArtifacts = await ethers.getContractFactory(contractName);

    // let deployed;
    // if (upgradable) {
    //     const upgradeableContract = await upgrades.deployProxy(contractArtifacts, contractArgs);
    //     deployed = await upgradeableContract.deployed();
    // } else {
    //     deployed = await contractArtifacts.deploy(...contractArgs);
    // }

    const deployed = await contractArtifacts.deploy(...contractArgs);
    const encoded = abiEncodeArgs(deployed, contractArgs);
    fs.writeFileSync(`artifacts/${contractName}.address`, deployed.address);

    console.log(" 📄", chalk.cyan(contractName), "deployed to:", chalk.magenta(deployed.address));

    if (!encoded || encoded.length <= 2) return deployed;
    fs.writeFileSync(`artifacts/${contractName}.args`, encoded.slice(2));

    return deployed;
};

// abi encodes contract arguments
// useful when you want to manually verify the contracts
// for example, on Etherscan
const abiEncodeArgs = (deployed: Contract, contractArgs: any[]) => {
    // not writing abi encoded args if this does not pass
    // || !R.hasPath(["interface", "deploy"], deployed)
    if (!contractArgs || !deployed ) {
        return "";
    }
    const encoded = utils.defaultAbiCoder.encode(deployed.interface.deploy.inputs, contractArgs);
    return encoded;
};

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error: Error) => {
        console.error(error);
        process.exit(1);
    });
