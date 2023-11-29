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

    const TheiaSwapIDKeeper = await hre.ethers.deployContract("TheiaSwapIDKeeper", [evn[networkName.toUpperCase()].MPC]);
    await TheiaSwapIDKeeper.waitForDeployment();
    console.log("TheiaSwapIDKeeper :", TheiaSwapIDKeeper.target);

    const TheiaRouter = await hre.ethers.deployContract("TheiaRouter", [evn[networkName.toUpperCase()].wNATIVE, evn[networkName.toUpperCase()].MPC
        , TheiaSwapIDKeeper.target, evn[networkName.toUpperCase()].C3CallerProxy, 1]);
    await TheiaRouter.waitForDeployment();
    console.log("TheiaRouter :", TheiaRouter.target);

    await TheiaSwapIDKeeper.addSupportedCaller(TheiaRouter.target)

    // const TheiaSwapIDKeeper = await hre.ethers.getContractAt("TheiaSwapIDKeeper", evn[networkName.toUpperCase()].TheiaSwapIDKeeper);
    // const TheiaRouter = await hre.ethers.getContractAt("TheiaRouter", evn[networkName.toUpperCase()].TheiaRouter);

    await hre.run("verify:verify", {
        address: TheiaSwapIDKeeper.target,
        contract: "contracts/routerV2/TheiaSwapIDKeeper.sol:TheiaSwapIDKeeper",
        constructorArguments: [evn[networkName.toUpperCase()].MPC],
    });

    await hre.run("verify:verify", {
        address: TheiaRouter.target,
        contract: "contracts/routerV2/TheiaRouter.sol:TheiaRouter",
        constructorArguments: [evn[networkName.toUpperCase()].wNATIVE, evn[networkName.toUpperCase()].MPC
            , TheiaSwapIDKeeper.target, evn[networkName.toUpperCase()].C3CallerProxy, 1],
    });

}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
