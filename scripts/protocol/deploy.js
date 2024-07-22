const hre = require("hardhat");
const evn = require("../../output/env.json")

let { join } = require('path')
let { readFile, writeFile } = require('fs')
let filePath = join(__dirname, '../../output/env.json')

let ARB = 421614

async function main() {
    const networkName = hre.network.name
    const chainId = hre.network.config.chainId
    console.log("Deploy Network name=", networkName);
    console.log("Network chain id=", chainId);

    console.log("wNATIVE", evn[networkName.toUpperCase()].wNATIVE);

    let feeData = await hre.ethers.provider.getFeeData()
    console.log("feeData", feeData);

    const [signer] = await ethers.getSigners()
    console.log("Deploying account:", signer.address);
    console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(signer.address), "ETH"));

    if (chainId == 5611) {//opbnb_test
        delete feeData["gasPrice"]
    }

    let c3SwapIDKeeper
    if (!evn[networkName.toUpperCase()].C3UUIDKeeper) {
        c3SwapIDKeeper = await hre.ethers.deployContract("contracts/protocol/C3UUIDKeeper.sol:C3UUIDKeeper", [], feeData);
        await c3SwapIDKeeper.waitForDeployment();
    } else {
        c3SwapIDKeeper = await hre.ethers.getContractAt("contracts/protocol/C3UUIDKeeper.sol:C3UUIDKeeper", evn[networkName.toUpperCase()].C3UUIDKeeper);
    }
    console.log('"C3UUIDKeeper":', `"${c3SwapIDKeeper.target}",`);

    let c3Caller
    if (!evn[networkName.toUpperCase()].C3Caller) {
        c3Caller = await hre.ethers.deployContract("contracts/protocol/C3Caller.sol:C3Caller", [c3SwapIDKeeper.target], feeData);
        await c3Caller.waitForDeployment();
    } else {
        c3Caller = await hre.ethers.getContractAt("contracts/protocol/C3Caller.sol:C3Caller", evn[networkName.toUpperCase()].C3Caller);
    }
    console.log('"C3Caller":', `"${c3Caller.target}",`);

    let c3DappManager
    if (chainId == ARB) {
        if (!evn[networkName.toUpperCase()].C3DappManager) {
            c3DappManager = await hre.ethers.deployContract("C3DappManager", [], feeData);
            await c3DappManager.waitForDeployment();
        } else {
            c3DappManager = await hre.ethers.getContractAt("C3DappManager", evn[networkName.toUpperCase()].C3DappManager);
        }
    } else {
        c3DappManager = { target: "0x0000000000000000000000000000000000000000" }
    }
    console.log('"C3DappManager":', `"${c3DappManager.target}",`);


    let c3CallerProxy
    if (!evn[networkName.toUpperCase()].C3CallerProxy) {
        const C3CallerProxy = await hre.ethers.getContractFactory("C3CallerProxy");
        c3CallerProxy = await hre.upgrades.deployProxy(
            C3CallerProxy,
            [c3Caller.target],
            { initializer: 'initialize', kind: 'uups', txOverrides: feeData }
        );
        await c3CallerProxy.waitForDeployment();
    } else {
        // TODO
        c3CallerProxy = { target: evn[networkName.toUpperCase()].C3CallerProxy }
    }
    console.log('"C3CallerProxy":', `"${c3CallerProxy.target}",`);

    let currentImplAddress = evn[networkName.toUpperCase()].C3CallerProxyImp
    if (!currentImplAddress) {
        currentImplAddress = await hre.upgrades.erc1967.getImplementationAddress(c3CallerProxy.target);
    }
    console.log('"C3CallerProxyImp":', `"${currentImplAddress}",`);

    let c3governor
    if (!evn[networkName.toUpperCase()].C3Governor) {
        c3governor = await hre.ethers.deployContract("contracts/protocol/C3Governor.sol:C3Governor", [], feeData);
        await c3governor.waitForDeployment();
    } else {
        c3governor = await hre.ethers.getContractAt("contracts/protocol/C3Governor.sol:C3Governor", evn[networkName.toUpperCase()].C3Governor);
    }
    console.log('"C3Governor":', `"${c3governor.target}",`);

    upData(networkName.toUpperCase(), {
        "C3UUIDKeeper": c3SwapIDKeeper.target,
        "C3Caller": c3Caller.target,
        "C3DappManager": c3DappManager.target,
        "C3CallerProxy": c3CallerProxy.target,
        "C3CallerProxyImp": currentImplAddress,
        "C3Governor": c3governor.target,
    })

    try {
        await c3SwapIDKeeper.addOperator(c3Caller.target, feeData)
        console.log(`c3SwapIDKeeper addOperator success ${c3Caller.target}`);
    } catch (error) {
        console.log(error)
    }
    try {
        // add c3CallerProxy to Operator
        await c3Caller.addOperator(currentImplAddress, feeData)
        console.log(`c3Caller addOperator success ${currentImplAddress}`);
    } catch (error) {
        console.log(error)
    }
    try {
        // for real call
        await c3Caller.addOperator(c3CallerProxy.target, feeData)

        console.log(`c3Caller addOperator success ${c3CallerProxy.target}`);
    } catch (error) {
        console.log(error)
    }

    for (let index = 0; index < evn.mpcList.length; index++) {
        try {
            const element = evn.mpcList[index];
            console.log(`c3Caller addOperator ${element.addr} ...`);
            await c3Caller.addOperator(element.addr, feeData)
            console.log(`c3Caller addOperator success ${element.addr}`);
        } catch (error) {
            console.log(error)
        }
    }

    for (let index = 0; index < evn.mpcList.length; index++) {
        try {
            const element = evn.mpcList[index];
            console.log(`c3CallerProxy addOperator ${element.addr} ...`);
            await c3CallerProxy.addOperator(element.addr, feeData)
            console.log(`c3CallerProxy addOperator success ${element.addr}`);
        } catch (error) {
            console.log(error)
        }
    }

    console.log(`npx hardhat verify --network ${networkName} ${c3SwapIDKeeper.target}`);
    console.log(`npx hardhat verify --network ${networkName} ${c3Caller.target} ${c3SwapIDKeeper.target}`);
    console.log(`npx hardhat verify --network ${networkName} ${c3DappManager.target} `);
    console.log(`npx hardhat verify --network ${networkName} ${currentImplAddress}`);
    console.log(`npx hardhat verify --network ${networkName} ${c3governor.target}`);

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

    if (ARB == chainId) {
        await hre.run("verify:verify", {
            address: c3DappManager.target,
            contract: "contracts/protocol/C3DappManager.sol:C3DappManager",
            constructorArguments: [],
        });
    }

    await hre.run("verify:verify", {
        address: currentImplAddress,
        contract: "contracts/protocol/C3CallerProxy.sol:C3CallerProxy",
        constructorArguments: [],
    });

    await hre.run("verify:verify", {
        address: c3governor.target,
        contract: "contracts/protocol/C3Governor.sol:C3Governor",
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