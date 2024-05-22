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
  HUMANODE_TEST
} = require("./env.json")


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
    }
  },
  etherscan: {
    apiKey: {
      bscTestnet: BSC_TEST.API_KEY,
      sepolia: SEPOLIA.API_KEY,
      arbitrumSepolia: ARB_TEST.API_KEY,
      sonic: SONIC.API_KEY,
      arb_test: ARB_TEST.API_KEY,
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
      }
    ]
  }
};
