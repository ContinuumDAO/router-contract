const hre = require("hardhat");
const evn = require("../../env.json")

let { join } = require('path')
let { readFile, writeFile } = require('fs')
let filePath = join(__dirname, '../../env.json')
console.log(filePath)

async function main() {
    const networkName = hre.network.name
    const chainId = hre.network.config.chainId
    console.log("Deploy Network name=", networkName);
    console.log("Network chain id=", chainId);

    console.log("wNATIVE", evn[networkName.toUpperCase()].wNATIVE);

    const [signer] = await ethers.getSigners()
    console.log("Deploying account:", signer.address);
    console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(signer.address), "ETH"));

    const aRouterConfig = await hre.ethers.deployContract("TheiaRouterConfig", [,evn[networkName.toUpperCase()].C3CallerProxy, 1]);
    await aRouterConfig.waitForDeployment();

    console.log('"TheiaRouterConfig":', `"${aRouterConfig.target}",`);

    const TheiaSwapIDKeeper = await hre.ethers.deployContract("TheiaSwapIDKeeper", [evn[networkName.toUpperCase()].MPC]);
    await TheiaSwapIDKeeper.waitForDeployment();
    console.log('"TheiaSwapIDKeeper":', `"${TheiaSwapIDKeeper.target}",`);


    const TheiaRouter = await hre.ethers.deployContract("TheiaRouter", [evn[networkName.toUpperCase()].wNATIVE, TheiaSwapIDKeeper.target, aRouterConfig.target,
    evn[networkName.toUpperCase()].FEE_TOKEN, evn[networkName.toUpperCase()].MPC, evn[networkName.toUpperCase()].C3CallerProxy, 1]);
    await TheiaRouter.waitForDeployment();
    console.log('"TheiaRouter":', `"${TheiaRouter.target}",`);

    await TheiaSwapIDKeeper.addSupportedCaller(TheiaRouter.target)

    upData(networkName.toUpperCase(), {
        "TheiaSwapIDKeeper": TheiaSwapIDKeeper.target,
        "TheiaRouter": TheiaRouter.target,
        "TheiaRouterConfig": aRouterConfig.target
    })

    console.log(`INSERT INTO router_config ( chain_id, router_address, contract_version) VALUES (
        '${chainId}',
        '${aRouterConfig.target}',
        'v1'
    );`)

    // const TheiaSwapIDKeeper = await hre.ethers.getContractAt("TheiaSwapIDKeeper", evn[networkName.toUpperCase()].TheiaSwapIDKeeper);
    // const TheiaRouter = await hre.ethers.getContractAt("TheiaRouter", evn[networkName.toUpperCase()].TheiaRouter);
    // const aRouterConfig = await hre.ethers.getContractAt("TheiaRouterConfig", evn[networkName.toUpperCase()].TheiaRouterConfig);

    console.log(`npx hardhat verify --network ${networkName} ${aRouterConfig.target} ${evn[networkName.toUpperCase()].C3CallerProxy} 1`);
    console.log(`npx hardhat verify --network ${networkName} ${TheiaSwapIDKeeper.target} ${signer.address}`);
    console.log(`npx hardhat verify --network ${networkName} ${TheiaRouter.target} ${evn[networkName.toUpperCase()].wNATIVE} ${TheiaSwapIDKeeper.target} ${aRouterConfig.target} ${evn[networkName.toUpperCase()].FEE_TOKEN} ${evn[networkName.toUpperCase()].MPC} ${evn[networkName.toUpperCase()].C3CallerProxy} 1`);

    await hre.run("verify:verify", {
        address: aRouterConfig.target,
        contract: "contracts/routerV2/TheiaRouterConfig.sol:TheiaRouterConfig",
        constructorArguments: [evn[networkName.toUpperCase()].C3CallerProxy, 1],
    });

    await hre.run("verify:verify", {
        address: TheiaSwapIDKeeper.target,
        contract: "contracts/routerV2/TheiaSwapIDKeeper.sol:TheiaSwapIDKeeper",
        constructorArguments: [evn[networkName.toUpperCase()].MPC],
    });

    await hre.run("verify:verify", {
        address: TheiaRouter.target,
        contract: "contracts/routerV2/TheiaRouter.sol:TheiaRouter",
        constructorArguments: [evn[networkName.toUpperCase()].wNATIVE, TheiaSwapIDKeeper.target, aRouterConfig.target,
        evn[networkName.toUpperCase()].FEE_TOKEN, evn[networkName.toUpperCase()].MPC, evn[networkName.toUpperCase()].C3CallerProxy, 1],
    });

}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

function upData(key, obj) {
    readFile(filePath, 'utf-8', (err, data) => {
        if (err) throw err
        let res = JSON.parse(data)

        res[key] = Object.assign(res[key], obj)

        writeFile(filePath, JSON.stringify(res, null, 4), err => {
            if (err) throw err
        })
    })
}