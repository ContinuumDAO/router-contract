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

    const aRouterConfig = await hre.ethers.deployContract("TheiaRouterConfig");
    await aRouterConfig.waitForDeployment();

    console.log('"TheiaRouterConfig":', `"${aRouterConfig.target}",`);

    await hre.run("verify:verify", {
        address: aRouterConfig.target,
        contract: "contracts/routerV2/TheiaRouterConfig.sol:TheiaRouterConfig",
        constructorArguments: [],
    });
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
