import hre from "hardhat";
import { getContracts } from "./utils";
import { ethers, upgrades } from "hardhat";

async function main() {
  const network = hre.network.name;
  const contracts = await getContracts(network)[network];

  // Upgrade WorkoutTreasury contract
  const WorkoutTreasury = await ethers.getContractFactory("WorkoutTreasury");
  const workoutTreasury = await upgrades.upgradeProxy(
    contracts.workoutTreasury,
    WorkoutTreasury
  );
  await workoutTreasury.waitForDeployment();
  const workoutTreasuryAddress = await workoutTreasury.getAddress();

  console.log("WorkoutTreasury proxy:", workoutTreasuryAddress);

  const currentImplAddress = await upgrades.erc1967.getImplementationAddress(
    workoutTreasuryAddress
  );

  console.log("Current implementation address:", currentImplAddress);

  // Add try catch since proxy already verified
  try {
    console.log(
      await hre.run("verify:verify", {
        address: contracts.workoutTreasury,
        constructorArguments: [],
      })
    );
  } catch (error: any) {
    console.log("Error verifying WorkoutTreasury:", error?.message);
  }

  console.log("Completed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
