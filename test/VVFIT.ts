import { expect } from "chai";
import { ethers } from "hardhat";
import { AddressLike, parseEther, Signer } from "ethers";
import {
  INonfungiblePositionManager,
  ISwapRouter,
  VVFIT,
  ISwapFactory,
} from "../typechain-types";
import { IWETH } from "typechain-types/contracts/interfaces/IWETH";
import bn from "bignumber.js";

bn.config({ EXPONENTIAL_AT: 999999, DECIMAL_PLACES: 40 });

describe("VVFIT Contract", function () {
  let VVFIT;
  let vvfit: VVFIT;
  let nonfungiblePositionManager: INonfungiblePositionManager;
  let weth: IWETH;
  let swapRouter: ISwapRouter;
  let swapFactory: ISwapFactory;
  let owner: Signer, addr1: Signer, addr2: Signer, addr3: Signer;

  let vvfitAddress: AddressLike,
    ownerAddress: AddressLike,
    addr1Address: AddressLike,
    addr2Address: AddressLike,
    addr3Address: AddressLike;

  const nonfungiblePositionManagerAddress =
    "0xC36442b4a4522E871399CD717aBDD847Ab11FE88"; // Uniswap v3 position manager
  const wethAddress = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"; // WETH
  const swapRouterAddress = "0xE592427A0AEce92De3Edee1F18E0157C05861564"; // Uniswap V3 swap router
  const swapFactoryAddress = "0x1F98431c8aD98523631AE4a59f267346ea31F984"; // Uniswap V3 swap factory

  before(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();
    ownerAddress = await owner.getAddress();
    addr1Address = await addr1.getAddress();
    addr2Address = await addr2.getAddress();
    addr3Address = await addr3.getAddress();

    weth = await ethers.getContractAt("IWETH", wethAddress, owner);

    nonfungiblePositionManager = await ethers.getContractAt(
      "INonfungiblePositionManager",
      nonfungiblePositionManagerAddress,
      owner
    );

    swapRouter = await ethers.getContractAt(
      "ISwapRouter",
      swapRouterAddress,
      owner
    );

    swapFactory = await ethers.getContractAt(
      "ISwapFactory",
      swapFactoryAddress,
      owner
    );
  });

  beforeEach(async function () {
    // Deploy the VVFIT contract
    VVFIT = await ethers.getContractFactory("VVFIT");
    // Deploy the VVFIT contract with initial values
    vvfit = await VVFIT.deploy("VVFIT Token", "VVFIT", 10000, 10000, 50000);
    await vvfit.waitForDeployment();
    vvfitAddress = await vvfit.getAddress();
  });

  describe("Deployment", function () {
    it("Should set the correct token name and symbol", async function () {
      expect(await vvfit.name()).to.equal("VVFIT Token");
      expect(await vvfit.symbol()).to.equal("VVFIT");
    });

    it("Should set initial purchase and sales tax percentages", async function () {
      expect(await vvfit.purchaseTaxPercent()).to.equal(10000);
      expect(await vvfit.salesTaxPercent()).to.equal(10000);
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

    it("Should allow the owner to update purchase tax", async function () {
      const newTax = 15000; // 15%
      await vvfit.setPercentageOfPurchaseTax(newTax);

      expect(await vvfit.purchaseTaxPercent()).to.equal(newTax);
    });

    it("Should not allow non-owners to update purchase tax", async function () {
      await expect(vvfit.connect(addr1).setPercentageOfPurchaseTax(15000))
        .to.be.revertedWithCustomError(vvfit, "OwnableUnauthorizedAccount")
        .withArgs(addr1Address);
    });
  });

  describe("Trading fees", function () {
    it("Should charge fee on buy token", async function () {
      await initializePool({
        vvfit,
        weth,
        nonfungiblePositionManager,
        swapRouter,
        swapFactory,
        ownerAddress,
        vvfitAddress,
        wethAddress,
        nonfungiblePositionManagerAddress,
        swapRouterAddress,
      });

      expect(await vvfit.balanceOf(vvfitAddress)).to.equal(0);

      // Buy token
      await weth.connect(addr1).deposit({ value: parseEther("20") });
      await weth.connect(addr1).approve(swapRouterAddress, parseEther("20"));

      const swapParams = {
        tokenIn: wethAddress,
        tokenOut: vvfitAddress,
        fee: 3000,
        recipient: addr1Address,
        deadline: Math.floor(Date.now() / 1000) + 60 * 24,
        amountIn: parseEther("1"),
        amountOutMinimum: 100,
        sqrtPriceLimitX96: 0,
      };
      await swapRouter.connect(addr1).exactInputSingle(swapParams);

      // Expect balance of vvfit token increase after swap with buy tax
      expect(await vvfit.balanceOf(vvfitAddress)).to.gt(0);
      console.log(
        "Balance after swap (buy):",
        await vvfit.balanceOf(vvfitAddress)
      );
    });

    it("Should be revert with IIA error", async function () {
      await initializePool({
        vvfit,
        weth,
        nonfungiblePositionManager,
        swapRouter,
        swapFactory,
        ownerAddress,
        vvfitAddress,
        wethAddress,
        nonfungiblePositionManagerAddress,
        swapRouterAddress,
      });

      expect(await vvfit.balanceOf(vvfitAddress)).to.equal(0);

      // Mint token
      await vvfit.mint(addr1Address, parseEther("20"));
      await vvfit.connect(addr1).approve(swapRouterAddress, parseEther("20"));

      const swapParams = {
        tokenIn: vvfitAddress,
        tokenOut: wethAddress,
        fee: 3000,
        recipient: addr1Address,
        deadline: Math.floor(Date.now() / 1000) + 60 * 24,
        amountIn: parseEther("1"),
        amountOutMinimum: 100,
        sqrtPriceLimitX96: 0,
      };
      await expect(
        swapRouter.connect(addr1).exactInputSingle(swapParams)
      ).to.be.revertedWith("IIA"); // Insufficient input amount for uniswap V3 not support fee on transfer token
    });
  });
});

async function initializePool({
  vvfit,
  weth,
  nonfungiblePositionManager,
  swapRouter,
  swapFactory,
  ownerAddress,
  vvfitAddress,
  wethAddress,
  nonfungiblePositionManagerAddress,
  swapRouterAddress,
}: {
  vvfit: VVFIT;
  weth: IWETH;
  nonfungiblePositionManager: INonfungiblePositionManager;
  swapRouter: ISwapRouter;
  swapFactory: ISwapFactory;
  ownerAddress: AddressLike;
  vvfitAddress: AddressLike;
  wethAddress: AddressLike;
  nonfungiblePositionManagerAddress: AddressLike;
  swapRouterAddress: AddressLike;
}) {
  const MIN_TICK = -887272;
  const MAX_TICK = 887272;
  const TICK_SPACING = 60;

  await vvfit.mint(ownerAddress, parseEther("1000"));
  await vvfit.approve(nonfungiblePositionManagerAddress, parseEther("1000"));

  await weth.deposit({ value: parseEther("20") });
  await weth.approve(nonfungiblePositionManagerAddress, parseEther("20"));

  const token0 = vvfitAddress < wethAddress ? vvfitAddress : wethAddress;
  const token1 = vvfitAddress < wethAddress ? wethAddress : vvfitAddress;

  const sqrtPriceX96 = BigInt(
    new bn("1") // reserve token 1
      .div("1") // reserve token 0
      .sqrt()
      .multipliedBy(new bn(2).pow(96))
      .integerValue(3)
      .toString()
  );

  await nonfungiblePositionManager.createAndInitializePoolIfNecessary(
    token0,
    token1,
    BigInt(3000),
    sqrtPriceX96
  );

  // 24 hours from now
  const deadline = Math.floor(Date.now() / 1000) + 60 * 24;

  const params = {
    token0: token0,
    token1: token1,
    fee: 3000,
    tickLower: Math.ceil(MIN_TICK / TICK_SPACING) * TICK_SPACING,
    tickUpper: Math.floor(MAX_TICK / TICK_SPACING) * TICK_SPACING,
    amount0Desired: parseEther("10"),
    amount1Desired: parseEther("10"),
    amount0Min: 0,
    amount1Min: 0,
    recipient: ownerAddress,
    deadline: deadline,
  };

  await nonfungiblePositionManager.mint(params);

  await vvfit.approve(swapRouterAddress, parseEther("200"));

  await weth.approve(swapRouterAddress, parseEther("20"));

  // Test swap
  const swapParams = {
    tokenIn: token0,
    tokenOut: token1,
    fee: 3000,
    recipient: ownerAddress,
    deadline: deadline,
    amountIn: parseEther("1"),
    amountOutMinimum: 100,
    sqrtPriceLimitX96: 0,
  };
  await swapRouter.exactInputSingle(swapParams);

  const poolAddress = await swapFactory.getPool(token0, token1, 3000);

  await vvfit.addPoolAddress(poolAddress);

  console.log("Initialize succeeded");
}
