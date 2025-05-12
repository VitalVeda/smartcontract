import hre from "hardhat";
import { getContracts, saveContract } from "../utils";
import { ethers } from "hardhat";

export default async function main() {
  const network = hre.network.name;
  const contracts = await getContracts(network)[network];

  // Deploy VVWIN contract
  const VVWIN = await ethers.getContractFactory("VVWINToken");
  const vvwinToken = await VVWIN.deploy(
    "VVWIN",
    "VVWIN",
    contracts.vvfitToken,
    5000, // conversion rate (20_000 VVWIN = 1 VVFIT), divided by denom 10^8, calculated by formula: 1 VVWIN = (input / 10^8) VVFIT
    ethers.parseEther("100000") // conversion threshold
  );

  await vvwinToken.waitForDeployment();
  const vvwinTokenAddress = await vvwinToken.getAddress();

  console.log("VVWIN Token deployed to:", vvwinTokenAddress);

  saveContract(network, "vvwinToken", vvwinTokenAddress);

  console.log("VVWIN Token contract address saved completed!");
}

// Uncomment this if doing a sole deployment
// main()
//   .then(() => process.exit(0))
//   .catch((error) => {
//     console.error(error);
//     process.exit(1);
//   });
