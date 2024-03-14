require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades")
require("./scripts/theiaRouter/erc20")

const {
  BSC_TEST,
  GOERLI,
  MUMBAI,
  ARB_TEST,
  OP_GOERLI,
  SONIC,
  SEPOLIA
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
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 1000,
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
    goerli: {
      url: GOERLI.URL,
      chainId: 5,
      accounts: [GOERLI.DEPLOY_KEY]
    },
    mumbai: {
      url: MUMBAI.URL,
      chainId: 80001,
      accounts: [MUMBAI.DEPLOY_KEY]
    },
    arb_test: {
      url: ARB_TEST.URL,
      chainId: 421614,
      accounts: [ARB_TEST.DEPLOY_KEY]
    },
    op_goerli: {
      url: OP_GOERLI.URL,
      gasPrice: OP_GOERLI.GASPRICE,
      chainId: 420,
      accounts: [OP_GOERLI.DEPLOY_KEY]
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
    }
  },
  etherscan: {
    apiKey: {
      bscTestnet: BSC_TEST.API_KEY,
      goerli: GOERLI.API_KEY,
      sepolia: SEPOLIA.API_KEY,
      polygonMumbai: MUMBAI.API_KEY,
      arbitrumSepolia: ARB_TEST.API_KEY,
      optimisticGoerli: OP_GOERLI.API_KEY,
    },
    customChains: [
      {
        network: "sonic",
        chainId: 64165,
        urls: {
          apiURL: SONIC.URL,
          browserURL: "https://public-sonic.fantom.network",
          apiKey: SONIC.API_KEY
        }
      }
    ]
  }
};
