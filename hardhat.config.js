require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades")
require("./scripts/theiaRouter/erc20")

const {
  BSC_TEST,
  ARB_TEST,
  SONIC,
  SEPOLIA,
  BLAST_SEP,
  AMOY,
  AERON_TEST,
  MANTA_TEST,
  LINEA_SEPOLIA,
  VANGUARD,
  HUMANODE_TEST,
  FIRE_TEST,
  AVAC_TEST,
  RARI_TEST,
  BARTIO,
  LUKSO_TEST,
  CORE_TEST,
  HOLESKY,
  BITLAYER_TEST,
  CRONOS_TEST,
  BASE_SEPOLIA,
  CFX_ESPACE
} = require("./output/env.json")


task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners()

  for (const account of accounts) {
    console.info(account.address)
  }
});

task("balance", "Prints an account's balance")
  .addParam("account", "The account's address")
  .setAction(async (taskArgs) => {
    const balance = await ethers.provider.getBalance(taskArgs.account);

    console.log(ethers.formatEther(balance), "ETH");
  });

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  defaultNetwork: "hardhat",
  solidity: {
    version: "0.8.19",
    settings: {
      // viaIR: true,
      optimizer: {
        enabled: true,
        runs: 200,
      }
    }
  },
  networks: {
    hardhat: {
    },
    bsc_test: {
      url: BSC_TEST.URL,
      chainId: 97,
      gasPrice: BSC_TEST.GASPRICE,
      accounts: [BSC_TEST.DEPLOY_KEY]
    },
    arb_test: {
      url: ARB_TEST.URL,
      chainId: 421614,
      accounts: [ARB_TEST.DEPLOY_KEY]
    },
    sonic: {
      url: SONIC.URL,
      chainId: 64165,
      accounts: [SONIC.DEPLOY_KEY]
    },
    sepolia: {
      url: SEPOLIA.URL,
      chainId: 11155111,
      accounts: [SEPOLIA.DEPLOY_KEY]
    },
    blast_sep: {
      url: BLAST_SEP.URL,
      chainId: 168587773,
      accounts: [BLAST_SEP.DEPLOY_KEY],
      gasPrice: 1000000000,
    },
    amoy: {
      url: AMOY.URL,
      chainId: 80002,
      accounts: [AMOY.DEPLOY_KEY]
    },
    aeron_test: {
      url: AERON_TEST.URL,
      chainId: 462,
      accounts: [AERON_TEST.DEPLOY_KEY]
    },
    manta_test: {
      url: MANTA_TEST.URL,
      chainId: 3441006,
      accounts: [MANTA_TEST.DEPLOY_KEY]
    },
    linea_sepolia: {
      url: LINEA_SEPOLIA.URL,
      chainId: 59141,
      accounts: [LINEA_SEPOLIA.DEPLOY_KEY]
    },
    vanguard: {
      url: VANGUARD.URL,
      chainId: 78600,
      accounts: [VANGUARD.DEPLOY_KEY]
    },
    humanode_test: {
      url: HUMANODE_TEST.URL,
      chainId: 14853,
      accounts: [HUMANODE_TEST.DEPLOY_KEY]
    },
    fire_test: {
      url: FIRE_TEST.URL,
      chainId: 997,
      accounts: [FIRE_TEST.DEPLOY_KEY]
    },
    avac_test: {
      url: AVAC_TEST.URL,
      chainId: 43113,
      accounts: [AVAC_TEST.DEPLOY_KEY]
    },
    rari_test: {
      url: RARI_TEST.URL,
      chainId: 1918988905,
      accounts: [RARI_TEST.DEPLOY_KEY]
    },
    bArtio: {
      url: BARTIO.URL,
      chainId: BARTIO.CHAINID,
      accounts: [BARTIO.DEPLOY_KEY]
    },
    lukso_test: {
      url: LUKSO_TEST.URL,
      chainId: LUKSO_TEST.CHAINID,
      accounts: [LUKSO_TEST.DEPLOY_KEY]
    },
    core_test: {
      url: CORE_TEST.URL,
      chainId: CORE_TEST.CHAINID,
      accounts: [CORE_TEST.DEPLOY_KEY]
    },
    holesky: {
      url: HOLESKY.URL,
      chainId: HOLESKY.CHAINID,
      accounts: [HOLESKY.DEPLOY_KEY]
    },
    bitlayer_test: {
      url: BITLAYER_TEST.URL,
      chainId: BITLAYER_TEST.CHAINID,
      accounts: [BITLAYER_TEST.DEPLOY_KEY]
    },
    cronos_test: {
      url: CRONOS_TEST.URL,
      chainId: CRONOS_TEST.CHAINID,
      accounts: [CRONOS_TEST.DEPLOY_KEY]
    },
    base_sepolia: {
      url: BASE_SEPOLIA.URL,
      chainId: BASE_SEPOLIA.CHAINID,
      accounts: [BASE_SEPOLIA.DEPLOY_KEY]
    },
    cfx_espace: {
      url: CFX_ESPACE.URL,
      chainId: CFX_ESPACE.CHAINID,
      accounts: [CFX_ESPACE.DEPLOY_KEY]
    }
  },
  etherscan: {
    apiKey: {
      bscTestnet: BSC_TEST.API_KEY,
      sepolia: SEPOLIA.API_KEY,
      arbitrumSepolia: ARB_TEST.API_KEY,
      sonic: SONIC.API_KEY,
      arb_test: ARB_TEST.API_KEY,
      avalancheFujiTestnet: AVAC_TEST.API_KEY,
      cronos_test: CRONOS_TEST.API_KEY
    },
    customChains: [
      {
        network: "sonic",
        chainId: 64165,
        urls: {
          apiURL: SONIC.URL,
          browserURL: "https://public-sonic.fantom.network",
        }
      },
      {
        network: "arb_test",
        chainId: 421614,
        urls: {
          apiURL: "https://api-sepolia.arbiscan.io/api",
          browserURL: "https://sepolia.arbiscan.io/",
        }
      },
      {
        network: "cronos_test",
        chainId: CRONOS_TEST.CHAINID,
        urls: {
          apiURL: "https://explorer-api.cronos.org/testnet/api/v1/hardhat/contract?apikey=" + CRONOS_TEST.API_KEY,
          browserURL: "http://explorer.cronos.org/testnet"
        }
      }
    ]
  }
};
