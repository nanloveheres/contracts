import { Contract } from 'ethers' 
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'

import { ethers } from "hardhat";
import chai from "chai";
import { solidity } from "ethereum-waffle";

chai.use(solidity);
const { expect } = chai;

describe("Token", () => { 

  let contract: Contract;

  let owner: SignerWithAddress;
  let alice: SignerWithAddress;
  let bob: SignerWithAddress;

  beforeEach(async () => {
    [owner, alice, bob] = await ethers.getSigners();
    const TestToken = await ethers.getContractFactory("TestToken");

    contract = await TestToken.deploy();
    await contract.deployed();
    console.info(`contract: ${contract.address}`)
    expect(await contract.totalSupply()).to.eq(0);
  });


  describe("Mint", async () => {
    it("Should mint some tokens", async () => {
      const toMint = ethers.utils.parseEther("1");

      await contract.connect(owner).mint(owner.address, toMint);
      expect(await contract.totalSupply()).to.eq(toMint);
    });
  });

  describe("Transfer", async () => {
    it("Should transfer tokens between users", async () => { 
      const toMint = ethers.utils.parseEther("1");

      await contract.connect(owner).mint(alice.address, toMint);
      expect(await contract.balanceOf(alice.address)).to.eq(toMint);

      const toSend = ethers.utils.parseEther("0.4");
      await contract.connect(alice).transfer(bob.address, toSend);

      expect(await contract.balanceOf(bob.address)).to.eq(toSend);
    });

    it("Should fail to transfer with low balance", async () => {
      const toMint = ethers.utils.parseEther("1");

      await contract.connect(owner).mint(alice.address, toMint);
      expect(await contract.balanceOf(alice.address)).to.eq(toMint);
 
      const toSend = ethers.utils.parseEther("1.1");

      // Notice await is on the expect
      await expect(contract.connect(alice).transfer(bob.address, toSend)).to.be.revertedWith(
        "transfer amount exceeds balance",
      );
    });
  });
});
