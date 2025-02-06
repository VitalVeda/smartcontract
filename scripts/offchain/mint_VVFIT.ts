import hre from "hardhat";
import { getContracts } from "../utils";
import { parseEther } from "ethers";

async function main() {
  const network = hre.network.name;
  const contracts = await getContracts(network)[network];

  const mintAddress = "0x307be72563d40540F668C1102db33c12F4ff0782";

  const vvfitToken = await hre.ethers.getContractAt(
    "VVFIT",
    contracts.vvfitToken
  );

  await vvfitToken.mint(mintAddress, parseEther("100"));

  console.log("Mint success");

  console.log("Completed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
