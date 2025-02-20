import hre from "hardhat";
import { getContracts } from "./utils";
import { ethers, upgrades } from "hardhat";

async function main() {
  const network = hre.network.name;
  const contracts = await getContracts(network)[network];

  // Upgrade WorkoutManagement contract
  const WorkoutManagement = await ethers.getContractFactory(
    "WorkoutManagement"
  );
  const workoutManagement = await upgrades.upgradeProxy(
    contracts.workoutManagement,
    WorkoutManagement
  );
  await workoutManagement.waitForDeployment();
  const workoutManagementAddress = await workoutManagement.getAddress();

  console.log("WorkoutManagement proxy:", workoutManagementAddress);

  // Add try catch since proxy already verified
  try {
    console.log(
      await hre.run("verify:verify", {
        address: contracts.workoutManagement,
        constructorArguments: [],
      })
    );
  } catch (error: any) {
    console.log("Error verifying WorkoutManagement:", error?.message);
  }

  console.log("Completed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
