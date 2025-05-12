import hre from "hardhat";
import { getContracts } from "../utils";
import { parseEther } from "ethers";

async function main() {
  const network = hre.network.name;
  const contracts = await getContracts(network)[network];

  const mintAddress = "0x9Fe6Ce95B33ab2F66cC2578BE41fE318C9c5Ae37";

  const vvfitToken = await hre.ethers.getContractAt(
    "VVFIT",
    contracts.vvfitToken
  );

  await vvfitToken.mint(mintAddress, parseEther("50000"));

  console.log("Mint success");

  console.log("Completed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
