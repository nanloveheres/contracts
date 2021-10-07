const ethers = require("ethers")

const ether = n => {
    return ethers.utils.parseEther(n.toString()).toString()
}

module.exports = async function (deployer, network, accounts) {
    const [alice] = accounts
    const deploy = async (name, ...args) => {
        const Artifacts = artifacts.require(`./${name}.sol`)
        await deployer.deploy(Artifacts, ...args)
        return Artifacts.deployed()
    }

    const FEE_LAY_EGG = ether(100)
    const FEE_CHANGE_TRIBE = ether(1)
    const FEE_UPGRADE_GENERATION = ether(5)
    const MARKET_ADDRESS = "TGXBEpgRyzsBrabjvnSuN2FeKSStoxXue2"

    // EVB
    const gameToken = await deploy("SafeToken", "Evelyn Token (Test)", "T-EVB", ether(10 ** 10))

    // EEX
    const rewardToken = await deploy("SafeToken", "Evelyn Explorer Token (Test)", "T-EEX", ether(10 ** 10))
    
    // random
    const random = await deploy("PseudoRandom")

    // manager
    const gameManager = await deploy("GameManager")
    console.info(`manager: ${gameManager.address}`)
    await gameManager.setPropsU256("feeLayEgg", FEE_LAY_EGG)
    await gameManager.setPropsU256("feeChangeTribe", FEE_CHANGE_TRIBE)
    await gameManager.setPropsU256("feeUpgradeGeneration", FEE_UPGRADE_GENERATION)
    await gameManager.setFeeAddress(MARKET_ADDRESS)

    // nft
    const nft = await deploy("NFT", "Evelyn Explorer NFT", "EVEX", gameManager.address)

    // fight
    const gameFight = await deploy("GameFight", nft.address, gameManager.address, random.address)

    // gamefi
    const gameFi = await deploy("GameFi", nft.address, gameToken.address, rewardToken.address, gameManager.address, gameFight.address, random.address)
    gameManager.addRole("SPAWN", gameFi.address)
    gameManager.addRole("BATTLE", gameFi.address)
    const isSpwanRole = await gameManager.isRole("SPAWN", gameFi.address)
    console.info(`gamefi SPAWN role: ${isSpwanRole}`)

    await gameToken.transfer(alice.address, ether(10000))
    await rewardToken.transfer(gameFi.address, ether(10000000))
    console.info(`GameFi lanched.`)
}
