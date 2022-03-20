import { config as dotenvConfig } from "dotenv";
import { resolve } from "path";
dotenvConfig({ path: resolve(__dirname, "./.env") });

import { HardhatUserConfig } from "hardhat/types";
import { NetworkUserConfig } from "hardhat/types";

import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";


const chainIds = {
  mumbai: 80001,
  mainnet: 137,
  hardhat: 31337,
};

const PRIVATE_KEY = process.env.PRIVATE_KEY || "";
const MNEMONIC = process.env.MNEMONIC || "";
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";

function createTestnetConfig(network: keyof typeof chainIds): NetworkUserConfig {
  const url: string = "https://rpc-" + network + ".maticvigil.com";
  return {
    accounts: [PRIVATE_KEY],
    chainId: chainIds[network],
    url,
  };
}

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  defaultNetwork: "mumbai",
  networks: {
    hardhat: {
      accounts: {
        mnemonic: MNEMONIC,
      },
      chainId: chainIds.hardhat,
    },
    mainnet: createTestnetConfig("mainnet"),
    mumbai: createTestnetConfig("mumbai"),
  },
  solidity: {
    compilers: [
      {
        version: '0.8.13',
        settings: {
          optimizer: {
            enabled: true,
            runs: 100000,
          },
          metadata: {
            // do not include the metadata hash, since this is machine dependent
            // and we want all generated code to be deterministic
            // https://docs.soliditylang.org/en/v0.7.6/metadata.html
            bytecodeHash: 'none',
          },
        }
      },
    ],
  },
  etherscan: {
    apiKey: ETHERSCAN_API_KEY,
  },
  // paths: {
  //   sources: "./contracts",
  //   cache: "./cache",
  //   artifacts: "./artifacts"
  // },
};

export default config;
