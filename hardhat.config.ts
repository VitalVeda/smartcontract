import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-verify";
import "@openzeppelin/hardhat-upgrades";
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
    xdc: {
      url: "https://erpc.xinfin.network",
      chainId: 50,
      accounts: [privateKey],
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
    customChains: [
      {
        network: "xdc_apothem",
        chainId: 51,
        urls: {
          apiURL: "https://rpc.apothem.network",
          browserURL: "https://apothem.xdcscan.io/",
        },
      },
    ],
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  },
  sourcify: {
    enabled: true,
  },
};

export default config;
