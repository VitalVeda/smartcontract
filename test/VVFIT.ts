import { expect } from "chai";
import { ethers } from "hardhat";
import { AddressLike, Signer } from "ethers";
import { VVFIT } from "../typechain-types";
import bn from "bignumber.js";

bn.config({ EXPONENTIAL_AT: 999999, DECIMAL_PLACES: 40 });

describe("VVFIT Contract", function () {
  let VVFIT;
  let vvfit: VVFIT;
  let owner: Signer, addr1: Signer, addr2: Signer, addr3: Signer;

  let vvfitAddress: AddressLike,
    ownerAddress: AddressLike,
    addr1Address: AddressLike,
    addr2Address: AddressLike,
    addr3Address: AddressLike;

  before(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();
    ownerAddress = await owner.getAddress();
    addr1Address = await addr1.getAddress();
    addr2Address = await addr2.getAddress();
    addr3Address = await addr3.getAddress();
  });

  beforeEach(async function () {
    // Deploy the VVFIT contract
    VVFIT = await ethers.getContractFactory("VVFIT");
    // Deploy the VVFIT contract with initial values
    vvfit = await VVFIT.deploy("VVFIT Token", "VVFIT", 50000);
    await vvfit.waitForDeployment();
    vvfitAddress = await vvfit.getAddress();
  });

  describe("Deployment", function () {
    it("Should set the correct token name and symbol", async function () {
      expect(await vvfit.name()).to.equal("VVFIT Token");
      expect(await vvfit.symbol()).to.equal("VVFIT");
    });

    it("Should set max transfer percentages", async function () {
      expect(await vvfit.maxTransferPercentage()).to.equal(50000);
    });

    it("Should whitelist the owner and contract addresses", async function () {
      expect(await vvfit.whitelist(ownerAddress)).to.equal(true);
      expect(await vvfit.whitelist(vvfitAddress)).to.equal(true);
    });
  });

  describe("Minting", function () {
    it("Should allow the owner to mint tokens", async function () {
      const mintAmount = ethers.parseUnits("100", 18);
      await vvfit.mint(addr1Address, mintAmount);

      expect(await vvfit.balanceOf(addr1Address)).to.equal(mintAmount);
      expect(await vvfit.totalSupply()).to.equal(mintAmount);
    });

    it("Should emit a Minted event on minting", async function () {
      const mintAmount = ethers.parseUnits("100", 18);
      await expect(vvfit.mint(addr1Address, mintAmount))
        .to.emit(vvfit, "Minted")
        .withArgs(ownerAddress, addr1Address, mintAmount);
    });

    it("Should not allow non-owners to mint tokens", async function () {
      await expect(
        vvfit.connect(addr1).mint(addr1Address, ethers.parseUnits("100", 18))
      )
        .to.be.revertedWithCustomError(vvfit, "OwnableUnauthorizedAccount")
        .withArgs(addr1Address);
    });

    it("Should not allow to mint exceed maximum total supply", async function () {
      const MAXIMUM_TOTAL_SUPPLY = await vvfit.MAXIMUM_TOTAL_SUPPLY();
      const totalSupply = await vvfit.totalSupply();
      const mintAmount = MAXIMUM_TOTAL_SUPPLY + 1n;

      await expect(vvfit.mint(addr1Address, mintAmount))
        .to.be.revertedWithCustomError(vvfit, "ExceedsMaximumSupply")
        .withArgs(mintAmount, MAXIMUM_TOTAL_SUPPLY - totalSupply);
    });
  });

  describe("Transfers", function () {
    beforeEach(async function () {
      await vvfit.mint(ownerAddress, ethers.parseUnits("1000", 18));
    });

    it("Should allow transfers between whitelisted addresses", async function () {
      const transferAmount = ethers.parseUnits("100", 18);
      await vvfit.updateWhitelist(addr1Address, true);

      await vvfit.transfer(addr1Address, transferAmount);
      expect(await vvfit.balanceOf(addr1Address)).to.equal(transferAmount);
    });

    it("Should not allow transfers from blacklisted addresses", async function () {
      await vvfit.updateBlacklist(addr1Address, true);

      await expect(
        vvfit.connect(addr1).transfer(addr2Address, ethers.parseUnits("50", 18))
      ).to.be.revertedWithCustomError(vvfit, "BlacklistedAddress");
    });
  });

  describe("Pausable", function () {
    it("Should pause and unpause the contract", async function () {
      await vvfit.pause();
      expect(await vvfit.paused()).to.equal(true);

      await vvfit.unpause();
      expect(await vvfit.paused()).to.equal(false);
    });

    it("Should prevent transfers when paused", async function () {
      await vvfit.mint(addr1Address, ethers.parseUnits("100", 18));
      await vvfit.pause();

      await expect(
        vvfit.connect(addr1).transfer(addr1Address, ethers.parseUnits("50", 18))
      ).to.be.revertedWithCustomError(vvfit, "ContractPaused");
    });
  });

  describe("Owner-only Functions", function () {
    it("Should allow the owner to update blacklist", async function () {
      await vvfit.updateBlacklist(addr1Address, true);
      expect(await vvfit.blacklist(addr1Address)).to.equal(true);
    });

    it("Should allow the owner to update new max transfer percentage", async function () {
      const newMaxTransferPercentage = 15000; // 15% of the total supply
      await vvfit.setMaxTransferPercentage(newMaxTransferPercentage);

      expect(await vvfit.maxTransferPercentage()).to.equal(
        newMaxTransferPercentage
      );
    });
  });
});
