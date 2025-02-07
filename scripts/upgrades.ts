import hre from "hardhat";
import { getContracts } from "./utils";
import { ethers, upgrades } from "hardhat";
import { parseEther } from "ethers";

async function main() {
  const network = hre.network.name;
  const contracts = await getContracts(network)[network];

  // Upgrade WorkoutTreasury contract
  const WorkoutTreasury = await ethers.getContractFactory("WorkoutTreasury");
  const workoutTreasury = await upgrades.upgradeProxy(
    contracts.workoutTreasury,
    WorkoutTreasury,
    { constructorArgs: [contracts.vvfitToken] }
  );
  await workoutTreasury.waitForDeployment();
  const workoutTreasuryAddress = await workoutTreasury.getAddress();

  console.log("WorkoutTreasury proxy:", workoutTreasuryAddress);

  // Deploy WorkoutManagement contract
  const WorkoutManagement = await ethers.getContractFactory(
    "WorkoutManagement"
  );
  const workoutManagement = await upgrades.upgradeProxy(
    contracts.workoutManagement,
    WorkoutManagement,
    {
      constructorArgs: [
        contracts.vvfitTokenAddress,
        workoutTreasuryAddress,
        parseEther("5"), // 5 VVFIT
        30000, // instructor rate 30%
        30000, // burning rate 30%
      ],
    }
  );
  await workoutManagement.waitForDeployment();
  const workoutManagementAddress = await workoutManagement.getAddress();

  console.log("WorkoutManagement proxy:", workoutManagementAddress);

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
