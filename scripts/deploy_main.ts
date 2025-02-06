import hre from "hardhat";
import { saveContract } from "./utils";
import { ethers, upgrades } from "hardhat";
import { parseEther } from "ethers";

async function main() {
  const network = hre.network.name;

  const VVFIT = await ethers.getContractFactory("VVFIT");
  const vvfitToken = await VVFIT.deploy(
    "VitalVEDA",
    "VVFIT",
    50_000 // Maximum transfer 50% total supply
  );

  await vvfitToken.waitForDeployment();
  const vvfitTokenAddress = await vvfitToken.getAddress();

  console.log("VVFIT Token deployed to:", vvfitTokenAddress);

  saveContract(network, "vvfitToken", vvfitTokenAddress);

  // Deploy WorkoutTreasury contract
  const WorkoutTreasury = await ethers.getContractFactory("WorkoutTreasury");
  const workoutTreasury = await upgrades.deployProxy(WorkoutTreasury, [
    vvfitTokenAddress,
  ]);
  await workoutTreasury.waitForDeployment();
  const workoutTreasuryAddress = await workoutTreasury.getAddress();

  console.log("WorkoutTreasury deployed to:", workoutTreasuryAddress);
  saveContract(network, "workoutTreasury", workoutTreasuryAddress);

  // Deploy WorkoutManagement contract
  const WorkoutManagement = await ethers.getContractFactory(
    "WorkoutManagement"
  );
  const workoutManagement = await upgrades.deployProxy(WorkoutManagement, [
    vvfitTokenAddress,
    workoutTreasuryAddress,
    parseEther("5"), // 5 VVFIT
    30000, // instructor rate 30%
    30000, // burning rate 30%
  ]);
  await workoutManagement.waitForDeployment();
  const workoutManagementAddress = await workoutManagement.getAddress();

  console.log("WorkoutManagement deployed to:", workoutManagementAddress);
  saveContract(network, "workoutManagement", workoutManagementAddress);

  // Verification
  console.log(
    await hre.run("verify:verify", {
      address: vvfitTokenAddress,
      constructorArguments: ["VitalVEDA", "VVFIT", 50_000],
    })
  );
  // Add try catch since proxy already verified
  try {
    console.log(
      await hre.run("verify:verify", {
        address: workoutTreasuryAddress,
        constructorArguments: [],
      })
    );
  } catch (error: any) {
    console.log("Error verifying WorkoutTreasury:", error?.message);
  }

  try {
    console.log(
      await hre.run("verify:verify", {
        address: workoutManagementAddress,
        constructorArguments: [],
      })
    );
  } catch (error: any) {
    console.error("Error verifying WorkoutManagement:", error?.message);
  }

  console.log("Completed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
