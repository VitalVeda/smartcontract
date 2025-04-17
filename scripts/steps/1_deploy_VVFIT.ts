import hre from "hardhat";
import { saveContract } from "../utils";
import { ethers } from "hardhat";

export default async function main() {
  const network = hre.network.name;

  const VVFIT = await ethers.getContractFactory("VVFIT");
  const vvfitToken = await VVFIT.deploy(
    "VitalVEDA",
    "VVFIT",
    50_000 // Maximum transfer 50% total supply
  );

  await vvfitToken.waitForDeployment();
  const vvfitTokenAddress = await vvfitToken.getAddress();

  console.log("VVFIT Token deployed to:", vvfitTokenAddress);

  saveContract(network, "vvfitToken", vvfitTokenAddress);

  console.log("VVFIT Token contract address saved completed!");
}

// Uncomment this if doing a sole deployment
// main()
//   .then(() => process.exit(0))
//   .catch((error) => {
//     console.error(error);
//     process.exit(1);
//   });
