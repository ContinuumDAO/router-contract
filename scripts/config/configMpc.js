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

    for (const key in evn[networkName.toUpperCase()].mpcList) {
        let tx = await aRouterConfig.connect(signer).setMPCPubkey(key, evn[networkName.toUpperCase()].mpcList[key])
        console.log("Tx:", tx.hash, key, evn[networkName.toUpperCase()].mpcList[key]);
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});