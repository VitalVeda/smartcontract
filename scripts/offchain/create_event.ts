import hre from "hardhat";
import { getContracts } from "../utils";
import { parseEther } from "ethers";

async function main() {
  const network = hre.network.name;
  const contracts = await getContracts(network)[network];

  const workoutManagement = await hre.ethers.getContractAt(
    "WorkoutManagement",
    contracts.workoutManagement
  );

  const eventId = 5;
  const participantFee = parseEther("1");
  const eventStartTime = 1739503400;
  const eventEndTime = 1739504300;

  // Create event required VVFIT, instructor need to have VVFIT and approve for workoutManagement contract first
  await workoutManagement.createEvent(
    eventId,
    participantFee,
    eventStartTime,
    eventEndTime
  );

  console.log("Create event success");

  console.log("Completed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
