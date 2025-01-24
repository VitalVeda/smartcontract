import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-verify";
import "hardhat-contract-sizer";
import "dotenv/config";

const privateKey = process.env.PRIVATE_KEY || "";
const apiKey = process.env.API_KEY;

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.27",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      gas: 12000000,
      blockGasLimit: 0x1fffffffffffff,
      allowUnlimitedContractSize: true,
      forking: {
        url: "https://rpc.apothem.network",
      },
    },
    xdc_apothem: {
      url: "https://rpc.apothem.network",
      chainId: 51,
      accounts: [privateKey],
    },
    tbsc: {
      url: "https://data-seed-prebsc-2-s1.bnbchain.org:8545",
      chainId: 97,
      accounts: [privateKey],
    },
  },
  etherscan: {
    apiKey,
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  },
};

export default config;
