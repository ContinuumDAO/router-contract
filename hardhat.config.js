require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades")
require("./scripts/theiaRouter/erc20")

const {
  BSC_TEST,
  GOERLI
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
    }
  },
  etherscan: {
    apiKey: {
      bscTestnet: BSC_TEST.API_KEY,
      goerli: GOERLI.API_KEY
    }
  }
};
