import hre from "hardhat";
import { getContracts, saveContract } from "../utils";
import { ethers, upgrades } from "hardhat";
import { parseEther } from "ethers";

export default async function main() {
  const network = hre.network.name;
  const contracts = await getContracts(network)[network];

  // Deploy WorkoutManagement contract
  const WorkoutManagement = await ethers.getContractFactory(
    "WorkoutManagement"
  );
  const workoutManagement = await upgrades.deployProxy(WorkoutManagement, [
    contracts.vvfitToken,
    contracts.workoutTreasury,
    parseEther("0"), // 5 VVFIT
    0, // instructor rate 30%
    0, // burning rate 30%
    parseEther("0"), // minimum fee to join a challenge is 0 VVFIT
    parseEther("13500"), // max fee to join a challenge is 13500 VVFIT
  ]);
  await workoutManagement.waitForDeployment();
  const workoutManagementAddress = await workoutManagement.getAddress();

  console.log("WorkoutManagement deployed to:", workoutManagementAddress);
  saveContract(network, "workoutManagement", workoutManagementAddress);

  console.log("WorkoutManagement contract address saved completed!");

  const currentWorkoutManagementImplAddress =
    await upgrades.erc1967.getImplementationAddress(workoutManagementAddress);

  console.log(
    "Current WorkoutManagement implementation address:",
    currentWorkoutManagementImplAddress
  );
}

// Uncomment this if doing a sole deployment
// main()
//   .then(() => process.exit(0))
//   .catch((error) => {
//     console.error(error);
//     process.exit(1);
//   });
