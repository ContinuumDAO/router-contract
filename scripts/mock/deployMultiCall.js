const hre = require("hardhat");
const evn = require("../../output/env.json")

async function main() {
    const networkName = hre.network.name
    const chainId = hre.network.config.chainId
    console.log("Deploy Network name=", networkName);
    console.log("Network chain id=", chainId);

    console.log("wNATIVE", evn[networkName.toUpperCase()].wNATIVE);

    let feeData = await hre.ethers.provider.getFeeData()
    console.log("feeData", feeData);
    if (chainId == 5611) {//opbnb_test
        delete feeData["gasPrice"]
    } else {
        delete feeData["maxFeePerGas"]
        delete feeData["maxPriorityFeePerGas"]
    }

    const [signer] = await ethers.getSigners()
    console.log("Deploying account:", signer.address);
    console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(signer.address), "ETH"));

    const multicall3 = await hre.ethers.deployContract("Multicall3", feeData);
    await multicall3.waitForDeployment();
    console.log("multicall3 :", multicall3.target);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
