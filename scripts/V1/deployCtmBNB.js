const hre = require("hardhat");

const evn = require("../../env.json")

async function main() {
  const networkName = hre.network.name
  const chainId = hre.network.config.chainId
  console.log("Deploy Network name=", networkName);
  console.log("Network chain id=", chainId);

  console.log("wNATIVE", evn[networkName.toUpperCase()].wNATIVE);

  const [signer] = await ethers.getSigners()
  console.log("Deploying account:", signer.address);
  console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(signer.address), "ETH"));

  const aDeployTokenFactoryV1 = await hre.ethers.deployContract("DeployTokenFactoryV1");
  await aDeployTokenFactoryV1.waitForDeployment();

  console.log("DeployTokenFactoryV1 address:", aDeployTokenFactoryV1.target);

  await aDeployTokenFactoryV1.newToken("c3bnb","c3BNB", 18, evn[networkName.toUpperCase()].wNATIVE, evn[networkName.toUpperCase()].testRouter)
  // console.log("Router:", await deployRouterV1.routers("testRouter"));

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
