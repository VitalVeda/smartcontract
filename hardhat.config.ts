import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-verify";
import "@openzeppelin/hardhat-upgrades";
import "hardhat-contract-sizer";
import "dotenv/config";

const privateKey = process.env.PRIVATE_KEY || "";
const xdcApiKey = process.env.XDC_API_KEY || "";
const bscApiKey = process.env.BSC_API_KEY || "";

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
    apiKey: {
      xdc: xdcApiKey,
      xdc_apothem: xdcApiKey,
      tbsc: bscApiKey,
    },
    customChains: [
      {
        network: "xdc_apothem",
        chainId: 51,
        urls: {
          apiURL: "https://api-testnet.xdcscan.com/api",
          browserURL: "https://testnet.xdcscan.com/",
        },
      },
      {
        network: "xdc",
        chainId: 50,
        urls: {
          apiURL: "https://api.xdcscan.com/api",
          browserURL: "https://xdcscan.com/",
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
    enabled: false,
  },
};

export default config;
