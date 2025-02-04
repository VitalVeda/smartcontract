import hre from "hardhat";
import { getContracts } from "../utils";
import { parseEther } from "ethers";

// const { upgrades } = hre;

async function main() {
  const network = hre.network.name;
  const contracts = await getContracts(network)[network];

  const mintAddress = "0x826Ab0e98A4bAe20B8d8C708Ec49E8956283B81F";

  const vvfitToken = await hre.ethers.getContractAt(
    "VVFIT",
    contracts.vvfitToken
  );

  //   await vvfitToken.mint(mintAddress, parseEther("100"));
  console.log(await vvfitToken.balanceOf(contracts.vvfitToken));

  console.log("Mint success");

  console.log("Completed!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
