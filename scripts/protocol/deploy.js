const hre = require("hardhat");
const evn = require("../../output/env.json")

let { join } = require('path')
let { readFile, writeFile } = require('fs')
let filePath = join(__dirname, '../../output/env.json')

async function main() {
    const networkName = hre.network.name
    const chainId = hre.network.config.chainId
    console.log("Deploy Network name=", networkName);
    console.log("Network chain id=", chainId);

    console.log("wNATIVE", evn[networkName.toUpperCase()].wNATIVE);

    const [signer] = await ethers.getSigners()
    console.log("Deploying account:", signer.address);
    console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(signer.address), "ETH"));

    let c3SwapIDKeeper = evn[networkName.toUpperCase()].C3UUIDKeeper
    if (!c3SwapIDKeeper) {
        c3SwapIDKeeper = await hre.ethers.deployContract("contracts/protocol/C3UUIDKeeper.sol:C3UUIDKeeper", []);
        await c3SwapIDKeeper.waitForDeployment();
        console.log('"C3UUIDKeeper":', `"${c3SwapIDKeeper.target}",`);
    }

    let c3Caller = evn[networkName.toUpperCase()].C3Caller
    if (!c3Caller) {
        c3Caller = await hre.ethers.deployContract("contracts/protocol/C3Caller.sol:C3Caller", [c3SwapIDKeeper.target]);
        await c3Caller.waitForDeployment();
    }
    console.log('"C3Caller":', `"${c3Caller.target}",`);

    let c3DappManager = evn[networkName.toUpperCase()].C3DappManager
    if (!c3DappManager) {
        c3DappManager = await hre.ethers.deployContract("C3DappManager", []);
        await c3DappManager.waitForDeployment();
    }
    console.log('"C3DappManager":', `"${c3DappManager.target}",`);

    let c3CallerProxy = evn[networkName.toUpperCase()].C3CallerProxy
    if (!c3CallerProxy) {
        const C3CallerProxy = await hre.ethers.getContractFactory("C3CallerProxy");
        c3CallerProxy = await hre.upgrades.deployProxy(
            C3CallerProxy,
            [c3Caller.target],
            { initializer: 'initialize', kind: 'uups' }
        );
        await c3CallerProxy.waitForDeployment();
    }
    console.log('"C3CallerProxy":', `"${c3CallerProxy.target}",`);

    const currentImplAddress = await hre.upgrades.erc1967.getImplementationAddress(c3CallerProxy.target);
    console.log('"C3CallerProxyImp":', `"${currentImplAddress}",`);

    upData(networkName.toUpperCase(), {
        "C3UUIDKeeper": c3SwapIDKeeper.target,
        "C3Caller": c3Caller.target,
        "C3DappManager": c3DappManager.target,
        "C3CallerProxy": c3CallerProxy.target,
        "C3CallerProxyImp": currentImplAddress,
    })

    await c3SwapIDKeeper.addOperator(c3Caller.target)
    // add c3CallerProxy to Operator
    await c3Caller.addOperator(currentImplAddress)
    // await c3Caller.addOperator(c3CallerProxy.target)

    for (let index = 0; index < evn.mpcList.length; index++) {
        const element = evn.mpcList[index];
        await c3Caller.addOperator(element.addr)
    }

    console.log(`npx hardhat verify --network ${networkName} ${c3SwapIDKeeper.target}`);
    console.log(`npx hardhat verify --network ${networkName} ${c3Caller.target} ${c3SwapIDKeeper.target}`);
    console.log(`npx hardhat verify --network ${networkName} ${c3DappManager.target} `);
    console.log(`npx hardhat verify --network ${networkName} ${currentImplAddress}`);

    await hre.run("verify:verify", {
        address: c3SwapIDKeeper.target,
        contract: "contracts/protocol/C3UUIDKeeper.sol:C3UUIDKeeper",
        constructorArguments: [],
    });

    await hre.run("verify:verify", {
        address: c3Caller.target,
        contract: "contracts/protocol/C3Caller.sol:C3Caller",
        constructorArguments: [c3SwapIDKeeper.target],
    });

    await hre.run("verify:verify", {
        address: c3DappManager.target,
        contract: "contracts/protocol/C3DappManager.sol:C3DappManager",
        constructorArguments: [],
    });

    await hre.run("verify:verify", {
        address: currentImplAddress,
        contract: "contracts/protocol/C3CallerProxy.sol:C3CallerProxy",
        constructorArguments: [],
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