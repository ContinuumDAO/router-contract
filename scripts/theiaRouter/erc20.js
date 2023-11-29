const evn = require("../../env.json")
const fs = require("fs");
async function deploy(args, hre) {
    const networkName = hre.network.name.toUpperCase()
    const chainId = hre.network.config.chainId
    console.log(args, evn[networkName].TheiaRouter, chainId);
    const TheiaERC20 = await hre.ethers.deployContract("TheiaERC20", [args.name, args.symbol, args.decimals, args.underlying, evn[networkName].TheiaRouter]);
    const theiaERC20 = await TheiaERC20.waitForDeployment();
    console.log("TheiaERC20 :", theiaERC20.target);

    result = { name: args.name, symbol: args.symbol, decimals: args.decimals, underlying: args.underlying, address: theiaERC20.target, chain: networkName, chainId: chainId };
    fs.appendFileSync("ERC20-" + networkName + ".txt", JSON.stringify(result) + "\n");

    return hre.run("verify:verify", {
        address: theiaERC20.target,
        contract: "contracts/routerV2/TheiaERC20.sol:TheiaERC20",
        constructorArguments: [args.name, args.symbol, args.decimals, args.underlying, evn[networkName].TheiaRouter],
    });

}

task("erc20", "Deploys Theia ERC20 contract")
    .addPositionalParam("name", "The student wallet address")
    .addPositionalParam("symbol", "The student wallet address")
    .addPositionalParam("decimals", "The student wallet address")
    .addPositionalParam("underlying", "The student wallet address")
    .setAction(async (taskArgs, hre) => {
        await hre.run("compile");
        await deploy(taskArgs, hre).catch(async (error) => {
            console.error(error);
            process.exitCode = 1;
        });
    });