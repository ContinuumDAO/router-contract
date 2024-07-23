const evn = require("../../output/env.json")
const fs = require("fs");
async function deploy(args, hre) {
    const networkName = hre.network.name.toUpperCase()
    const chainId = hre.network.config.chainId

    const [signer] = await ethers.getSigners()
    console.log(args, evn[networkName].TheiaRouter, chainId, signer.address);
    let feeData = await hre.ethers.provider.getFeeData()
    console.log("feeData", feeData);
    if (chainId == 5611) {//opbnb_test
        delete feeData["gasPrice"]
    }

    const TheiaERC20 = await hre.ethers.deployContract("TheiaERC20", [args.name, args.symbol, args.decimals, args.underlying, evn[networkName].TheiaRouter]);
    const theiaERC20 = await TheiaERC20.waitForDeployment();
    console.log("TheiaERC20 :", theiaERC20.target, "owner:", await theiaERC20.owner(), "minters", await theiaERC20.getAllMinters());

    result = {
        name: args.name, symbol: args.symbol, decimals: args.decimals, underlying: args.underlying,
        address: theiaERC20.target, chain: networkName, chainId: chainId, router: evn[networkName].TheiaRouter
    };
    fs.appendFileSync("./output/ERC20.txt", JSON.stringify(result) + "\n");

    console.log(`npx hardhat verify --network ${networkName.toLowerCase()} ${theiaERC20.target} ${args.name} ${args.symbol} ${args.decimals} ${args.underlying} ${evn[networkName].TheiaRouter}`);

    try {
        hre.run("verify:verify", {
            address: theiaERC20.target,
            contract: "contracts/routerV2/TheiaERC20.sol:TheiaERC20",
            constructorArguments: [args.name, args.symbol, args.decimals, args.underlying, evn[networkName].TheiaRouter],
        });
    } catch (error) {
        console.log(error);
    }
}

task("erc20", "Deploys Theia ERC20 contract")
    .addPositionalParam("name", "token name")
    .addPositionalParam("symbol", "token symbol")
    .addPositionalParam("decimals", "token decimals")
    .addPositionalParam("underlying", "token underlying")
    .setAction(async (taskArgs, hre) => {
        await hre.run("compile");
        await deploy(taskArgs, hre).catch(async (error) => {
            console.error(error);
            process.exitCode = 1;
        });
    });