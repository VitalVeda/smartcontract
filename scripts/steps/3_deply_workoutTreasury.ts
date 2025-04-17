import hre from "hardhat";
import { getContracts, saveContract } from "../utils";
import { ethers, upgrades } from "hardhat";

export default async function main() {
  const network = hre.network.name;
  const contracts = await getContracts(network)[network];

  // Deploy WorkoutTreasury contract
  const WorkoutTreasury = await ethers.getContractFactory("WorkoutTreasury");
  const workoutTreasury = await upgrades.deployProxy(WorkoutTreasury, [
    contracts.vvfitToken,
  ]);
  await workoutTreasury.waitForDeployment();
  const workoutTreasuryAddress = await workoutTreasury.getAddress();

  console.log("WorkoutTreasury deployed to:", workoutTreasuryAddress);
  saveContract(network, "workoutTreasury", workoutTreasuryAddress);

  console.log("WorkoutTreasury contract address saved completed!");

  const currentWorkoutTreasuryImplAddress =
    await upgrades.erc1967.getImplementationAddress(workoutTreasuryAddress);

  console.log(
    "Current WorkoutTreasury implementation address:",
    currentWorkoutTreasuryImplAddress
  );
}

// Uncomment this if doing a sole deployment
// main()
//   .then(() => process.exit(0))
//   .catch((error) => {
//     console.error(error);
//     process.exit(1);
//   });
