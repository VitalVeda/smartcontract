import hre from "hardhat";
import { getContracts } from "../utils";
import { parseEther } from "ethers";

async function main() {
  const network = hre.network.name;
  const contracts = await getContracts(network)[network];

  const poolAddress = "0xf65566d81304c958b69e6e0957fc9b685f257b62";

  const vvfitToken = await hre.ethers.getContractAt(
    "VVFIT",
    contracts.vvfitToken
  );

  await vvfitToken.addPoolAddress(poolAddress);

  console.log("Add pool success");

  console.log("Completed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
