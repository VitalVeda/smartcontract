import hre from "hardhat";
import { saveContract } from "./utils";

async function main() {
  const network = hre.network.name;

  const VVFIT = await hre.ethers.getContractFactory("VVFIT");
  const vvfitToken = await VVFIT.deploy(
    "VitalVEDA",
    "VVFIT",
    50_000 // Maximum transfer 50% total supply
  );

  await vvfitToken.waitForDeployment();
  const vvfitTokenAddress = await vvfitToken.getAddress();
  saveContract(network, "vvfitToken", vvfitTokenAddress);
  console.log("VVFIT Token deployed to:", vvfitTokenAddress);

  console.log(
    await hre.run("verify:verify", {
      address: vvfitTokenAddress,
      constructorArguments: ["VitalVEDA", "VVFIT", 10_000, 10_000, 50_000],
    })
  );

  console.log("Completed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
