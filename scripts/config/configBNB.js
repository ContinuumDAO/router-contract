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

    const aRouterConfig = await hre.ethers.getContractAt("C3RouterConfig", evn[networkName.toUpperCase()].C3RouterConfig);
    console.log("C3RouterConfig address:", aRouterConfig.target);

    let tx = await aRouterConfig.connect(signer).setTokenConfig("bnb", chainId, evn[networkName.toUpperCase()].ctmBNB, 18, 1,
        evn[networkName.toUpperCase()].testRouter, "")
    console.log("Tx:", tx.hash);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
