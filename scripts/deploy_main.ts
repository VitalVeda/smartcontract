// Import the other scripts
import deployVVFIT from "./steps/1_deploy_VVFIT";
import deployVVWIN from "./steps/2_deploy_VVWIN";
import deployWorkoutTreasury from "./steps/3_deply_workoutTreasury";
import deployWorkoutManagement from "./steps/4_deploy_wokoutManagement";
import verifyContracts from "./steps/5_verify_contracts";

// Note to check the imported script has their main() commented before running this script
async function main() {
  console.log(`🚀 Starting deployment`);

  console.log("Start deploy VVFIT Token...");
  await deployVVFIT();

  console.log("Start deploy VVWIN Token...");
  await deployVVWIN();

  console.log("Start deploy Workout Treasury...");
  await deployWorkoutTreasury();

  console.log("Start deploy Workout Management...");
  await deployWorkoutManagement();

  console.log("Start verifying contracts...");
  await verifyContracts();

  console.log("Completed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
