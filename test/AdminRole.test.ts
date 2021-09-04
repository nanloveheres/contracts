import chai, { expect } from "chai";
import { BigNumber, Contract, Signer } from "ethers";
import { ether, toEther } from "./shared/util";
import { network, ethers } from "hardhat";
import { solidity } from "ethereum-waffle";

// chai.use(solidity);

describe("AdminRole", () => {
    let contract: Contract;

    beforeEach(async () => {
        const [owner, alice, bob] = await ethers.getSigners();
        const AdminRole = await ethers.getContractFactory("ExampleAdminRole");
        contract = await AdminRole.deploy(alice.address);
        await contract.deployed();
    });

    it("is admin", async () => {
        const [owner, alice, bob] = await ethers.getSigners();
        expect(await contract.isAdmin(owner.address), "deploy").eq(true);
        expect(await contract.isAdmin(alice.address), "alice admin").eq(false);
        expect(await contract.isAdmin(bob.address), "bob").eq(false);
        expect(await contract.hasRole(await contract.OWNER_ROLE(), alice.address), "alice owner").eq(true);
    });

    it("has role", async () => {
        const [owner, alice, bob] = await ethers.getSigners();
        const OWNER = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("OWNER"));
        const ADMIN = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("ADMIN"));
        expect(await contract.hasRole(OWNER, owner.address), "deployer is an ownner").eq(true);
        expect(await contract.hasRole(OWNER, alice.address), "alice is an ownner").eq(true);
        expect(await contract.hasRole(OWNER, bob.address), "bob isn't an ownner").eq(false);
        expect(await contract.hasRole(ADMIN, owner.address), "deployer is an admin").eq(true);
        expect(await contract.hasRole(ADMIN, alice.address), "alice is not an admin").eq(false);
        expect(await contract.hasRole(ADMIN, bob.address), "bob is not an admin").eq(false);
        await contract.connect(owner).addAdmin(bob.address);
        expect(await contract.hasRole(ADMIN, bob.address), "bob is an admin").eq(true);
    });

    it("destruct", async () => {
        const [owner, alice, bob] = await ethers.getSigners();
        await owner.sendTransaction({ to: contract.address, value: ether(1), gasLimit: 9999999 });
        expect(await ethers.provider.getBalance(contract.address)).to.be.eq(ether(1));

        const balanceAlice = await alice.getBalance();
        console.info(`bal (Alice): ${toEther(balanceAlice)}`);
        await contract.connect(alice).close({ gasLimit: 9999999 });
        const newBalanceAlice = await alice.getBalance();
        console.info(`new bal (Alice): ${toEther(newBalanceAlice)}`);
        const netAmount = toEther(newBalanceAlice.sub(balanceAlice));
        console.info(`nett amt (Alice): ${netAmount}`);
        expect(parseFloat(netAmount)).to.be.closeTo(1, 0.999);
    });
});
