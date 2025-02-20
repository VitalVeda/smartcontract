import { AddressLike, parseEther, Signer } from "ethers";
import { WorkoutManagement, VVFIT, WorkoutTreasury } from "typechain-types";
import { expect } from "chai";

import { ethers, network, upgrades } from "hardhat";

describe("WorkoutManagement", function () {
  let workoutManagement: WorkoutManagement;
  let vvfitToken: VVFIT;
  let workoutTreasury: WorkoutTreasury;
  let admin: Signer;
  let instructor: Signer;
  let participant: Signer;
  let operator: Signer;

  let vvfitTokenAddress: AddressLike,
    workoutManagementAddress: AddressLike,
    workoutTreasuryAddress: AddressLike,
    adminAddress: AddressLike,
    instructorAddress: AddressLike,
    participantAddress: AddressLike,
    operatorAddress: AddressLike;

  const EVENT_CREATION_FEE = parseEther("10");
  const PARTICIPATION_FEE = parseEther("1");
  const MIN_PARTICIPANT_FEE = parseEther("1");
  const MAX_PARTICIPANT_FEE = parseEther("5");
  const CONTRACT_NAME = "WorkoutManagement";
  const CONTRACT_VERSION = "1.0.0";

  before(async function () {
    [admin, instructor, participant, operator] = await ethers.getSigners();
    // Assign address
    adminAddress = await admin.getAddress();
    instructorAddress = await instructor.getAddress();
    participantAddress = await participant.getAddress();
    operatorAddress = await operator.getAddress();

    // Deploy VVFIT token
    const VVFIT = await ethers.getContractFactory("VVFIT");
    vvfitToken = await VVFIT.deploy("VVFIT Token", "VVFIT", 50000);
    await vvfitToken.waitForDeployment();
    vvfitTokenAddress = await vvfitToken.getAddress();

    // Deploy WorkoutTreasury contract
    const WorkoutTreasury = await ethers.getContractFactory("WorkoutTreasury");
    workoutTreasury = await upgrades.deployProxy(WorkoutTreasury, [
      vvfitTokenAddress,
    ]);
    await workoutTreasury.waitForDeployment();
    workoutTreasuryAddress = await workoutTreasury.getAddress();

    // Deploy WorkoutManagement contract
    const WorkoutManagement = await ethers.getContractFactory(
      "WorkoutManagement"
    );
    workoutManagement = await upgrades.deployProxy(WorkoutManagement, [
      vvfitTokenAddress,
      workoutTreasuryAddress,
      EVENT_CREATION_FEE,
      30000, // instructor rate 30%
      30000, // burning rate 30%
      MIN_PARTICIPANT_FEE,
      MAX_PARTICIPANT_FEE,
    ]);
    await workoutManagement.waitForDeployment();
    workoutManagementAddress = await workoutManagement.getAddress();

    // Grant roles
    await workoutManagement.grantInstructorRole(instructorAddress);
    await workoutManagement.grantOperatorRole(operatorAddress);

    // Mint VVFIT tokens for testing
    await vvfitToken.mint(instructorAddress, parseEther("1000"));
    await vvfitToken.mint(participantAddress, parseEther("1000"));
  });

  describe("Initialization", function () {
    it("should initialize with correct values", async function () {
      expect(await workoutManagement.vvfitToken()).to.equal(vvfitTokenAddress);
      expect(await workoutManagement.workoutTreasury()).to.equal(
        workoutTreasuryAddress
      );
      expect(await workoutManagement.eventCreationFee()).to.equal(
        EVENT_CREATION_FEE
      );
      expect(await workoutManagement.instructorRate()).to.equal(30000);
      expect(await workoutManagement.burningRate()).to.equal(30000);
    });
  });

  describe("Event Creation", function () {
    it("should allow an instructor to create an event", async function () {
      const currentTimestamp = await getCurrentTimestamp();
      const eventStartTime = currentTimestamp + 3600; // 1 hour from now
      const eventEndTime = eventStartTime + 7200; // 2 hours later
      const eventId = 0;

      await vvfitToken
        .connect(instructor)
        .approve(workoutManagementAddress, EVENT_CREATION_FEE);

      await expect(
        workoutManagement
          .connect(instructor)
          .createEvent(eventId, PARTICIPATION_FEE, eventStartTime, eventEndTime)
      )
        .to.emit(workoutManagement, "EventCreated")
        .withArgs(0, instructorAddress, eventEndTime);

      const event = await workoutManagement.events(0);
      expect(event.instructor).to.equal(instructorAddress);
      expect(event.participationFee).to.equal(PARTICIPATION_FEE);
      expect(event.eventStartTime).to.equal(eventStartTime);
      expect(event.eventEndTime).to.equal(eventEndTime);
    });

    it("should revert if participation fee is zero", async function () {
      const currentTimestamp = await getCurrentTimestamp();
      const eventStartTime = currentTimestamp + 3600;
      const eventEndTime = eventStartTime + 7200;
      const eventId = 1;

      await expect(
        workoutManagement
          .connect(instructor)
          .createEvent(eventId, 0, eventStartTime, eventEndTime)
      ).to.be.revertedWithCustomError(
        workoutManagement,
        "InvalidParticipationFee"
      );
    });

    it("should revert if event end time is in the past", async function () {
      const currentTimestamp = await getCurrentTimestamp();
      const eventStartTime = currentTimestamp - 3600;
      const eventEndTime = eventStartTime + 1800;
      const eventId = 1;

      await expect(
        workoutManagement
          .connect(instructor)
          .createEvent(eventId, PARTICIPATION_FEE, eventStartTime, eventEndTime)
      ).to.be.revertedWithCustomError(workoutManagement, "InvalidEventEndTime");
    });
  });

  describe("Event Participation", function () {
    it("should revert if event has not started", async function () {
      const eventId = 0;
      await expect(
        workoutManagement.connect(participant).participateInEvent(eventId)
      ).to.be.revertedWithCustomError(workoutManagement, "EventNotStart");
    });

    it("should allow a user to participate in an event", async function () {
      const eventId = 0;

      await network.provider.send("evm_increaseTime", [7200]); // Increase 2 hours to simulate the event starting time
      await network.provider.send("evm_mine");

      await vvfitToken
        .connect(participant)
        .approve(workoutManagementAddress, PARTICIPATION_FEE);

      await expect(
        workoutManagement.connect(participant).participateInEvent(eventId)
      )
        .to.emit(workoutManagement, "UserParticipated")
        .withArgs(eventId, participantAddress, PARTICIPATION_FEE);

      const event = await workoutManagement.events(eventId);
      expect(
        await workoutManagement.checkIsUserParticipated(
          eventId,
          participantAddress
        )
      ).to.be.true;
      expect(event.participants).to.equal(1);
    });

    it("should revert if user already participated", async function () {
      const eventId = 0;
      await expect(
        workoutManagement.connect(participant).participateInEvent(eventId)
      ).to.be.revertedWithCustomError(workoutManagement, "AlreadyParticipated");
    });
  });

  describe("Instructor Fee Claim", function () {
    it("should revert if event has not ended", async function () {
      const eventId = 0;
      await expect(
        workoutManagement.connect(instructor).instructorClaimFee(eventId)
      ).to.be.revertedWithCustomError(workoutManagement, "EventNotCompleted");
    });

    it("should allow an instructor to claim fees", async function () {
      const eventId = 0;
      await network.provider.send("evm_increaseTime", [7200]); // Increase additional 2 hours
      await network.provider.send("evm_mine");

      const instructorBalanceBefore = await vvfitToken.balanceOf(
        instructorAddress
      );

      await workoutManagement.connect(instructor).instructorClaimFee(eventId);

      const event = await workoutManagement.events(eventId);
      expect(event.instructorFeeClaimed).to.be.true;
      expect(await vvfitToken.balanceOf(instructorAddress)).to.eq(
        instructorBalanceBefore + parseEther("0.3")
      ); // 30% of 1 token
    });

    it("should revert if fees are already claimed", async function () {
      const eventId = 0;
      await expect(
        workoutManagement.connect(instructor).instructorClaimFee(eventId)
      ).to.be.revertedWithCustomError(workoutManagement, "FeesAlreadyClaimed");
    });
  });

  describe("Top Participants Reward Claim", function () {
    it("should allow a top participant to claim rewards", async function () {
      const eventId = BigInt(0);
      const rewardPercentage = BigInt(50000); // 50%
      const salt = BigInt(12345);

      const domain = {
        chainId: (await ethers.provider.getNetwork()).chainId,
        verifyingContract: workoutManagementAddress.toString(),
        name: CONTRACT_NAME,
        version: CONTRACT_VERSION,
      };

      const types = {
        Claim: [
          { name: "eventId", type: "uint256" },
          { name: "user", type: "address" },
          { name: "rewardPercentage", type: "uint256" },
          { name: "salt", type: "uint256" },
        ],
      };

      const value = {
        eventId: eventId,
        user: participantAddress.toString(),
        rewardPercentage: rewardPercentage,
        salt: salt,
      };

      // Sign the claim message
      const signature = await operator.signTypedData(domain, types, value);

      const event = await workoutManagement.events(eventId);
      const totalReward = event.rewardPool;

      await expect(
        workoutManagement
          .connect(participant)
          .topParticipantsClaimReward(
            eventId,
            rewardPercentage,
            salt,
            signature
          )
      )
        .to.emit(workoutManagement, "TopParticipantsClaimed")
        .withArgs(eventId, participantAddress, totalReward / 2n);
    });

    it("should revert if reward is already claimed", async function () {
      const eventId = 0;
      const rewardPercentage = 50000;
      const salt = 12345;

      const signature = await operator.signTypedData(
        {
          chainId: (await ethers.provider.getNetwork()).chainId,
          verifyingContract: workoutManagementAddress.toString(),
          name: CONTRACT_NAME,
          version: CONTRACT_VERSION,
        },
        {
          Claim: [
            { type: "uint256", name: "eventId" },
            { type: "address", name: "user" },
            { type: "uint256", name: "rewardPercentage" },
            { type: "uint256", name: "salt" },
          ],
        },
        {
          eventId: eventId,
          user: participantAddress,
          rewardPercentage: rewardPercentage,
          salt: salt,
        }
      );

      await expect(
        workoutManagement
          .connect(participant)
          .topParticipantsClaimReward(
            eventId,
            rewardPercentage,
            salt,
            signature
          )
      ).to.be.revertedWithCustomError(
        workoutManagement,
        "RewardAlreadyClaimed"
      );
    });

    it("should revert if salt is already used", async function () {
      const currentTimestamp = await getCurrentTimestamp();
      const eventStartTime = currentTimestamp + 3600; // 1 hour from now
      const eventEndTime = eventStartTime + 7200; // 2 hours later
      const eventId = 1;

      await vvfitToken
        .connect(instructor)
        .approve(workoutManagementAddress, EVENT_CREATION_FEE);

      await workoutManagement
        .connect(instructor)
        .createEvent(eventId, PARTICIPATION_FEE, eventStartTime, eventEndTime);

      await network.provider.send("evm_increaseTime", [7200]); // Increase 2 hours to simulate the event starting time
      await network.provider.send("evm_mine");

      await vvfitToken
        .connect(participant)
        .approve(workoutManagementAddress, PARTICIPATION_FEE);

      await workoutManagement.connect(participant).participateInEvent(eventId);

      await network.provider.send("evm_increaseTime", [7200]);
      await network.provider.send("evm_mine");

      const rewardPercentage = 50000;
      const salt = 12345;

      const signature = await operator.signTypedData(
        {
          chainId: (await ethers.provider.getNetwork()).chainId,
          verifyingContract: workoutManagementAddress.toString(),
          name: CONTRACT_NAME,
          version: CONTRACT_VERSION,
        },
        {
          Claim: [
            { type: "uint256", name: "eventId" },
            { type: "address", name: "user" },
            { type: "uint256", name: "rewardPercentage" },
            { type: "uint256", name: "salt" },
          ],
        },
        {
          eventId: eventId,
          user: participantAddress,
          rewardPercentage: rewardPercentage,
          salt: salt,
        }
      );

      await expect(
        workoutManagement
          .connect(participant)
          .topParticipantsClaimReward(
            eventId,
            rewardPercentage,
            salt,
            signature
          )
      ).to.be.revertedWithCustomError(workoutManagement, "SaltAlreadyUsed");
    });
  });

  describe("Emergency Withdraw", function () {
    it("should allow admin to withdraw tokens", async function () {
      const amount = parseEther("100");

      await vvfitToken.mint(workoutManagementAddress, amount);

      await expect(
        workoutManagement.connect(admin).emergencyWithdraw(amount, adminAddress)
      )
        .to.emit(workoutManagement, "EmergencyWithdraw")
        .withArgs(adminAddress, amount, adminAddress);
    });

    it("should revert if amount is zero", async function () {
      await expect(
        workoutManagement.connect(admin).emergencyWithdraw(0, adminAddress)
      ).to.be.revertedWithCustomError(workoutManagement, "ZeroAmount");
    });
  });
});

async function getCurrentTimestamp() {
  // Get the latest block
  const latestBlock = await ethers.provider.getBlock("latest");
  // Return the block's timestamp
  return latestBlock?.timestamp || 0;
}
