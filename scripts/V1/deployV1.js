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

  const deployRouterV1 = await hre.ethers.deployContract("DeployRouterV1");
  await deployRouterV1.waitForDeployment();
  console.log("deployRouterV1 address:", deployRouterV1.target);

  const deployC3SwapIDKeeper = await hre.ethers.deployContract("C3SwapIDKeeper", [signer.address]);
  await deployC3SwapIDKeeper.waitForDeployment();
  console.log("deployC3SwapIDKeeper address:", deployC3SwapIDKeeper.target);

  await deployRouterV1.newRouter(evn[networkName.toUpperCase()].wNATIVE, signer.address, deployC3SwapIDKeeper.target, "testRouter")
  console.log("Router:", await deployRouterV1.routers("testRouter"));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
