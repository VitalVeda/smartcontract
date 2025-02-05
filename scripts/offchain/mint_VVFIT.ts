import hre from "hardhat";
import { getContracts } from "../utils";
import { parseEther } from "ethers";

async function main() {
  const network = hre.network.name;
  const contracts = await getContracts(network)[network];

  const mintAddress = "0xB9Edf2E3Cf8194B15EC9ee23ee30d0A8B9Ea7DC9";

  const vvfitToken = await hre.ethers.getContractAt(
    "VVFIT",
    contracts.vvfitToken
  );

  await vvfitToken.mint(mintAddress, parseEther("1"));

  console.log("Mint success");

  console.log("Completed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
