const hre = require("hardhat");
const evn = require("../../output/env.json")

async function main() {
    const networkName = hre.network.name
    const chainId = hre.network.config.chainId
    console.log("Deploy Network name=", networkName);
    console.log("Network chain id=", chainId);

    console.log("wNATIVE", evn[networkName.toUpperCase()].wNATIVE);

    const [signer] = await ethers.getSigners()
    console.log("Deploying account:", signer.address);
    console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(signer.address), "ETH"));

    const CToken = await hre.ethers.deployContract("contracts/demo/CToken.sol:CToken", ["myCToken", "AAA", evn[networkName.toUpperCase()].C3CallerProxy, 2, 18]);
    await CToken.waitForDeployment();
    console.log("CToken :", CToken.target);

    await hre.run("verify:verify", {
        address: CToken.target,
        contract: "contracts/demo/CToken.sol:CToken",
        constructorArguments: ["myCToken", "AAA", evn[networkName.toUpperCase()].C3CallerProxy, 2, 18],
    });
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
