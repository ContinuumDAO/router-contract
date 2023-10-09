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

    const routerV1 = await hre.ethers.getContractAt("CtmDaoV1Router", evn[networkName.toUpperCase()].testRouter);
    console.log("CtmDaoV1Router address:", routerV1.target);

    let aops = await routerV1.getAllOperators()
    console.log("aops:", aops);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
