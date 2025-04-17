import { expect } from "chai";
import { ethers } from "hardhat";
import { AddressLike, Signer } from "ethers";
import { VVFIT, VVWINToken } from "../typechain-types";

// Constants
const BASE_DENOMINATOR = 10 ** 8;

// Deploy contract fixture
async function deployFixture() {
  const [admin, minter, user1, user2, recipient] = await ethers.getSigners();

  // Deploy mock VVFIT token
  const VVFIT = await ethers.getContractFactory("VVFIT");
  const vvfitToken = await VVFIT.deploy("VVFIT Token", "VVFIT", 50000);
  await vvfitToken.waitForDeployment();

  // Deploy VVWINToken contract
  const conversionRate = 5000; // 50% (1 VVWIN = 0.5 VVFIT)
  const conversionThreshold = ethers.parseEther("100");

  const VVWINToken = await ethers.getContractFactory("VVWINToken");
  const vvwinToken = await VVWINToken.deploy(
    "VVWIN",
    "VVWIN",
    vvfitToken.target,
    conversionRate,
    conversionThreshold
  );
  await vvwinToken.waitForDeployment();

  // Assign roles
  await vvwinToken.grantRole(
    await vvwinToken.DEFAULT_ADMIN_ROLE(),
    admin.address
  );
  await vvwinToken.grantRole(await vvwinToken.MINTER_ROLE(), minter.address);

  return {
    vvwinToken,
    vvfitToken,
    admin,
    minter,
    user1,
    user2,
    recipient,
    conversionRate,
    conversionThreshold,
  };
}

describe("VVWINToken", function () {
  let vvwinToken: VVWINToken,
    vvfitToken: VVFIT,
    admin: Signer,
    adminAddress: AddressLike,
    minter: Signer,
    minterAddress: AddressLike,
    user1: Signer,
    user1Address: AddressLike,
    user2: Signer,
    user2Address: AddressLike,
    recipient: Signer,
    recipientAddress: AddressLike,
    conversionRate: number,
    conversionThreshold: bigint;

  beforeEach(async function () {
    ({
      vvwinToken,
      vvfitToken,
      admin,
      minter,
      user1,
      user2,
      recipient,
      conversionRate,
      conversionThreshold,
    } = await deployFixture());
    adminAddress = await admin.getAddress();
    minterAddress = await minter.getAddress();
    user1Address = await user1.getAddress();
    user2Address = await user2.getAddress();
    recipientAddress = await recipient.getAddress();
  });

  describe("Minting", function () {
    it("Should allow minter to mint tokens", async function () {
      await vvwinToken
        .connect(minter)
        .mint(user1Address, ethers.parseEther("1"));
      expect(await vvwinToken.balanceOf(user1Address)).to.equal(
        ethers.parseEther("1")
      );
    });

    it("Should prevent non-minter from minting", async function () {
      await expect(
        vvwinToken.connect(user1).mint(user1Address, ethers.parseEther("1"))
      ).to.be.revertedWithCustomError(
        vvwinToken,
        "AccessControlUnauthorizedAccount"
      );
    });
  });

  describe("Transfers", function () {
    it("Should allow whitelisted users to transfer", async function () {
      await vvwinToken.grantRole(
        await vvwinToken.WHITELIST_ROLE(),
        user1Address
      );

      await vvwinToken
        .connect(minter)
        .mint(user1Address, ethers.parseEther("1"));
      await vvwinToken
        .connect(user1)
        .transfer(user2Address, ethers.parseEther("1"));
      expect(await vvwinToken.balanceOf(user2Address)).to.equal(
        ethers.parseEther("1")
      );
    });

    it("Should block non-whitelisted users from transferring", async function () {
      await vvwinToken
        .connect(minter)
        .mint(user2Address, ethers.parseEther("1"));
      await expect(
        vvwinToken.connect(user2).transfer(user1Address, ethers.parseEther("1"))
      ).to.be.revertedWithCustomError(vvwinToken, "TransferNotAllowed");
    });
  });

  describe("Auto-Conversion", function () {
    it("Should auto-convert if balance exceeds threshold", async function () {
      await vvwinToken.grantRole(
        await vvwinToken.WHITELIST_ROLE(),
        user1Address
      );

      const amountNearConvert = conversionThreshold - BigInt(1);

      await vvfitToken.mint(vvwinToken.target, ethers.parseEther("1000")); // Fund contract

      await vvwinToken.connect(minter).mint(user1Address, amountNearConvert);

      await vvwinToken.connect(minter).mint(user2Address, amountNearConvert);

      expect(await vvwinToken.balanceOf(user2Address)).to.equal(
        amountNearConvert
      );

      await vvwinToken.connect(user1).transfer(user2Address, BigInt(1));

      expect(await vvwinToken.balanceOf(user2Address)).to.equal(0); // Burned

      const expectedVVFIT =
        (conversionThreshold * BigInt(conversionRate)) /
        BigInt(BASE_DENOMINATOR);
      expect(await vvfitToken.balanceOf(user2Address)).to.equal(expectedVVFIT);

      await vvwinToken.connect(minter).mint(user1Address, BigInt(2));
      expect(await vvwinToken.balanceOf(user1Address)).to.equal(0); // Burned

      expect(await vvfitToken.balanceOf(user1Address)).to.equal(expectedVVFIT);
    });
  });

  describe("Admin Controls", function () {
    it("Should allow admin to pause/unpause", async function () {
      await vvwinToken.grantRole(
        await vvwinToken.WHITELIST_ROLE(),
        user1Address
      );

      const amountToTransfer = ethers.parseEther("1");

      await vvwinToken.connect(minter).mint(user1Address, amountToTransfer);
      await vvwinToken.connect(admin).pause();
      expect(await vvwinToken.paused()).to.equal(true);
      // Should not be operated on paused
      await expect(
        vvwinToken.connect(user1).transfer(user2Address, amountToTransfer)
      ).to.be.revertedWithCustomError(vvwinToken, "TransferNotAllowed");
      await expect(
        vvwinToken.connect(minter).mint(user1Address, amountToTransfer)
      ).to.be.revertedWithCustomError(vvwinToken, "EnforcedPause");

      await vvwinToken.connect(admin).unpause();
      expect(await vvwinToken.paused()).to.equal(false);
    });

    it("Should prevent non-admin from pausing", async function () {
      await expect(
        vvwinToken.connect(user1).pause()
      ).to.be.revertedWithCustomError(
        vvwinToken,
        "AccessControlUnauthorizedAccount"
      );
    });
  });

  describe("Emergency Withdraw", function () {
    it("Should allow admin to emergency withdraw VVFIT only when contract is paused", async function () {
      await vvfitToken.mint(vvwinToken.target, ethers.parseEther("500"));
      await expect(
        vvwinToken
          .connect(admin)
          .emergencyWithdrawVVFIT(recipientAddress, ethers.parseEther("200"))
      ).to.be.revertedWithCustomError(vvwinToken, "ExpectedPause");

      await vvwinToken.connect(admin).pause();
      await vvwinToken
        .connect(admin)
        .emergencyWithdrawVVFIT(recipientAddress, ethers.parseEther("200"));
      expect(await vvfitToken.balanceOf(recipientAddress)).to.equal(
        ethers.parseEther("200")
      );
    });
  });
});
