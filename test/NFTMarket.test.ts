import chai, { expect } from "chai"
import { BigNumber, Contract } from "ethers"
import { ether, toEther, parseUnits, mineTime } from "./shared/util"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { network, ethers } from "hardhat"

describe("NFT Market", () => {
    let owner: SignerWithAddress
    let alice: SignerWithAddress
    let bob: SignerWithAddress
    let market: SignerWithAddress

    let gameToken: Contract
    let nft: Contract
    let gameManager: Contract
    let nftMarket: Contract

    const MARKET_RATE = 300
    const MAX_AMOUNT = "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"

    beforeEach(async () => {
        ;[owner, alice, bob, market] = await ethers.getSigners()
        const ERC20Token = await ethers.getContractFactory("ERC20Token")
        const NFT = await ethers.getContractFactory("NFT")
        const GameManager = await ethers.getContractFactory("GameManager")
        const NFTMarket = await ethers.getContractFactory("NFTMarket")

        gameToken = await ERC20Token.deploy()

        // manager
        gameManager = await GameManager.deploy()
        await gameManager.setFeeAddress(market.address)
        await gameManager.setPropsU256("feeMarketRate", MARKET_RATE)

        // nft
        nft = await NFT.deploy("Space Man", "SPACEMAN", gameManager.address)

        // nft market
        nftMarket = await NFTMarket.deploy(nft.address, gameToken.address, gameManager.address)

        // allow owner mint
        gameManager.addRole("SPAWN", owner.address)
        // mint 3 nft for alice
        nft.layEgg(alice.address, [0, 1, 2])
        // mint 2 nft for bob
        nft.layEgg(bob.address, [1, 3])
    })

    it("Sale NFT#1", async () => {
        // approve transferring to the nft market
        await nft.connect(alice).setApprovalForAll(nftMarket.address, true)

        await nftMarket.connect(alice).placeOrder(1, ether(123))
        expect(await nftMarket.marketSize(), "market size").to.eq(1)
        expect(await nftMarket.orders(alice.address), "alice orders").to.eq(1)
        expect(await nftMarket.orders(bob.address), "bob orders").to.eq(0)
        expect(await nftMarket.tokenSaleByIndex(0), "tokenSale[0] -> nft id = 1").to.eq(1)
    })

    it("Sale NFT#2", async () => {
        await expect(nftMarket.connect(alice).placeOrder(2, ether(123)), "nft#2 not approve").to.be.reverted

        // approve transferring to the nft market
        await nft.connect(alice).setApprovalForAll(nftMarket.address, true)

        await nftMarket.connect(alice).placeOrder(2, ether(123))

        expect(await nftMarket.marketSize(), "market size").to.eq(1)
        expect(await nftMarket.orders(alice.address), "alice orders").to.eq(1)
        expect(await nftMarket.orders(bob.address), "bob orders").to.eq(0)
        expect(await nftMarket.tokenSaleByIndex(0), "tokenSale[0] -> nft id = 2").to.eq(2)
    })

    it("Buy NFT#1", async () => {
        // approve transferring to the nft market
        const NFT_COST = ether(123)
        await nft.connect(alice).setApprovalForAll(nftMarket.address, true)
        await nftMarket.connect(alice).placeOrder(1, NFT_COST)

        // bob got enough token to buy nft
        await gameToken.transfer(bob.address, NFT_COST)
        // approve market contract to use his token
        await gameToken.connect(bob).approve(nftMarket.address, MAX_AMOUNT)
        await nftMarket.connect(bob).fillOrder(1)
        expect(await nft.ownerOf(1), "owner = bob").to.eq(bob.address)

        expect(await gameToken.balanceOf(bob.address), "bob balance").to.eq(0)
        expect(await gameToken.balanceOf(alice.address), "alice balance").to.eq(NFT_COST.sub(NFT_COST.mul(MARKET_RATE).div(10000)))
    })

    it("Cancel Sale", async () => {
        // approve transferring to the nft market
        await nft.connect(alice).setApprovalForAll(nftMarket.address, true)

        await nftMarket.connect(alice).placeOrder(1, ether(123))
        expect(await nftMarket.marketSize(), "market size").to.eq(1)
        expect(await nftMarket.orders(alice.address), "alice orders").to.eq(1)
        expect(await nftMarket.tokenSaleByIndex(0), "tokenSale[0] -> nft id = 1").to.eq(1)

        await nftMarket.connect(alice).cancelOrder(1)
        expect(await nftMarket.marketSize(), "market size").to.eq(0)
        expect(await nftMarket.orders(alice.address), "alice orders").to.eq(0)
    })

    it("Update Sale", async () => {
        // approve transferring to the nft market
        await nft.connect(alice).setApprovalForAll(nftMarket.address, true)

        await nftMarket.connect(alice).placeOrder(1, ether(123))
        let saleItem = await nftMarket.getSale(1)
        expect(saleItem.price, "price = 123 ether").to.eq(ether(123))

        await nftMarket.connect(alice).updatePrice(1, ether(456))
        saleItem = await nftMarket.getSale(1)
        expect(saleItem.price, "price = 456 ether").to.eq(ether(456))
    })

    it("Sale NFT#1 & #3", async () => {
        // approve transferring to the nft market
        await nft.connect(alice).setApprovalForAll(nftMarket.address, true)

        await nftMarket.connect(alice).placeOrder(1, ether(123))
        expect(await nftMarket.marketSize(), "market size").to.eq(1)
        expect(await nftMarket.orders(alice.address), "alice orders").to.eq(1)
        expect(await nftMarket.orders(bob.address), "bob orders").to.eq(0)
        expect(await nftMarket.tokenSaleByIndex(0), "tokenSale[0] -> nft id = 1").to.eq(1)

        await nftMarket.connect(alice).placeOrder(3, ether(345))
        expect(await nftMarket.marketSize(), "market size").to.eq(2)
        expect(await nftMarket.orders(alice.address), "alice orders").to.eq(2)
        expect(await nftMarket.orders(bob.address), "bob orders").to.eq(0)
        expect(await nftMarket.tokenSaleByIndex(0), "tokenSale[0] -> nft id = 1").to.eq(1)
        expect(await nftMarket.tokenSaleByIndex(1), "tokenSale[1] -> nft id = 3").to.eq(3)
    })
})
