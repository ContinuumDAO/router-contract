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

    const USDC = await hre.ethers.deployContract("USDC");
    await USDC.waitForDeployment();
    console.log("USDC :", USDC.target);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
