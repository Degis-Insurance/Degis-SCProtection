import fs from "fs";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-waffle";
import "hardhat-deploy";
import "@typechain/hardhat";
import "hardhat-preprocessor";
import "@nomiclabs/hardhat-etherscan";
import "hardhat-contract-sizer";
import { HardhatUserConfig, task } from "hardhat/config";

import example from "./tasks/example";

import * as dotenv from "dotenv";
dotenv.config();

import "./tasks/setAddress";
import "./tasks/voting/onboard";
import "./tasks/executor/executor";

function getRemappings() {
  return fs
    .readFileSync("remappings.txt", "utf8")
    .split("\n")
    .filter(Boolean)
    .map((line) => line.trim().split("="));
}

task("example", "Example task").setAction(example);

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.15",
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 100,
      },
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
      localhost: 0,
      fuji: 0,
      avax: 0,
    },
  },
  networks: {
    hardhat: {},
    localhost: {},
    fuji: {
      url: process.env.FUJI_URL || "",
      accounts: {
        mnemonic:
          process.env.PHRASE_FUJI !== undefined ? process.env.PHRASE_FUJI : "",
        count: 20,
      },
      timeout: 60000,
    },
    avax: {
      url: process.env.AVAX_URL || "",
      accounts: {
        mnemonic:
          process.env.PHRASE_AVAX !== undefined ? process.env.PHRASE_AVAX : "",
        count: 20,
      },
    },
  },
  etherscan: {
    apiKey: {
      avalancheFujiTestnet: "CHSGYSXFKHQC7UX7MRAYW43Q238741N2N4",
    },
  },
  paths: {
    sources: "./src", // Use ./src rather than ./contracts as Hardhat expects
    cache: "./cache_hardhat", // Use a different cache for Hardhat than Foundry
    tests: "./test/hhtest",
  },
  // This fully resolves paths for imports in the ./lib directory for Hardhat
  preprocess: {
    eachLine: (hre) => ({
      transform: (line: string) => {
        if (line.match(/^\s*import /i)) {
          getRemappings().forEach(([find, replace]) => {
            if (line.match('"' + find)) {
              line = line.replace('"' + find, '"' + replace);
            }
          });
        }
        return line;
      },
    }),
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: false,
    only: [],
  },
};

export default config;
