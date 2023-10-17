require("@nomicfoundation/hardhat-toolbox");
const {
  BSC_TEST
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
      // gasPrice: BSC_TEST.GASPRICE,
      accounts: [BSC_TEST.DEPLOY_KEY]
    }
  },
  etherscan: {
    apiKey: {
      bscTestnet: BSC_TEST.API_KEY,
    }
  }
};
