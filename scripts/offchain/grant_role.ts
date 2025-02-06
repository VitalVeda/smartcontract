import hre from "hardhat";
import { getContracts } from "../utils";
import { parseEther } from "ethers";

async function main() {
  const network = hre.network.name;
  const contracts = await getContracts(network)[network];

  const newRoleAddress = "0x5148e3990341147Cc576585eC36026ef24c8f5D2";

  const workoutManagement = await hre.ethers.getContractAt(
    "WorkoutManagement",
    contracts.workoutManagement
  );

  // Grant instructor role
  await workoutManagement.grantInstructorRole(newRoleAddress);
  // Grant operator role
  //   await workoutManagement.grantOperatorRole(newRoleAddress);

  console.log("Grant role success");

  console.log("Completed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
