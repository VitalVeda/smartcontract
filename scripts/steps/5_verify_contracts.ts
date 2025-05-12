import hre from "hardhat";
import { getContracts } from "../utils";
import { ethers } from "hardhat";

export default async function main() {
  const network = hre.network.name;
  const contracts = await getContracts(network)[network];

  // Verification
  console.log(
    await hre.run("verify:verify", {
      address: contracts.vvfitToken,
      constructorArguments: ["VitalVEDA", "VVFIT", 50_000],
    })
  );
  // Verification
  console.log(
    await hre.run("verify:verify", {
      address: contracts.vvwinToken,
      constructorArguments: [
        "VVWIN",
        "VVWIN",
        contracts.vvfitToken,
        5000,
        ethers.parseEther("100000"),
      ],
    })
  );
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

  try {
    console.log(
      await hre.run("verify:verify", {
        address: contracts.workoutManagement,
        constructorArguments: [],
      })
    );
  } catch (error: any) {
    console.error("Error verifying WorkoutManagement:", error?.message);
  }
}

// Uncomment this if doing a sole deployment
// main()
//   .then(() => process.exit(0))
//   .catch((error) => {
//     console.error(error);
//     process.exit(1);
//   });
