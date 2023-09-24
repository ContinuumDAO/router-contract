const hre = require("hardhat");

const evn = require("../../env.json")

async function main() {
    const networkName = hre.network.name
    const chainId = hre.network.config.chainId
    console.log("Deploy Network name=", networkName);
    console.log("Network chain id=", chainId);

    const [signer] = await ethers.getSigners()
    console.log("Deploying account:", signer.address);
    console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(signer.address), "ETH"));

    const aRouterConfig = await hre.ethers.getContractAt("RouterConfig", evn[networkName.toUpperCase()].RouterConfig);
    console.log("RouterConfig address:", aRouterConfig.target);

    let tx = await aRouterConfig.connect(signer).setChainConfig(chainId, networkName, evn[networkName.toUpperCase()].testRouter, 2, 33587883, "{}")
    console.log("Tx:", tx.hash);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
