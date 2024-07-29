const hre = require("hardhat");
const evn = require("../../output/env.json")
const { Web3 } = require('web3');


let { join } = require('path')
let { readFile, writeFile } = require('fs')
let filePath = join(__dirname, '../../output/env.json')
console.log(filePath)

async function main() {

    const networkName = hre.network.name
    const chainId = hre.network.config.chainId
    console.log("Deploy Network name=", networkName);
    console.log("Network chain id=", chainId);

    console.log("wNATIVE", evn[networkName.toUpperCase()].wNATIVE);
    let web3 = new Web3(evn[networkName.toUpperCase()].URL);

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

    let gov = signer.address;
    if (chainId == 421614) {
        gov = evn[networkName.toUpperCase()].C3Governor
    }

    let aRouterConfig = evn[networkName.toUpperCase()].TheiaRouterConfig
    if (!aRouterConfig) {
        aRouterConfig = await hre.ethers.deployContract("TheiaRouterConfig", [gov, evn[networkName.toUpperCase()].C3CallerProxy, signer.address, 1], feeData);
        await aRouterConfig.waitForDeployment();
    } else {
        aRouterConfig = await hre.ethers.getContractAt("TheiaRouterConfig", evn[networkName.toUpperCase()].TheiaRouterConfig);
    }
    console.log('"TheiaRouterConfig":', `"${aRouterConfig.target}",`);

    let TheiaUUIDKeeper = evn[networkName.toUpperCase()].TheiaUUIDKeeper
    if (!TheiaUUIDKeeper) {
        TheiaUUIDKeeper = await hre.ethers.deployContract("TheiaUUIDKeeper", [gov, evn[networkName.toUpperCase()].C3CallerProxy, signer.address, 1], feeData);
        await TheiaUUIDKeeper.waitForDeployment();
    } else {
        TheiaUUIDKeeper = await hre.ethers.getContractAt("TheiaUUIDKeeper", evn[networkName.toUpperCase()].TheiaUUIDKeeper);
    }
    console.log('"TheiaUUIDKeeper":', `"${TheiaUUIDKeeper.target}",`);

    let FeeManager = evn[networkName.toUpperCase()].FeeManager
    if (!FeeManager) {
        FeeManager = await hre.ethers.deployContract("FeeManager", [gov, evn[networkName.toUpperCase()].C3CallerProxy, signer.address, 1], feeData);
        await FeeManager.waitForDeployment();
    } else {
        FeeManager = await hre.ethers.getContractAt("FeeManager", evn[networkName.toUpperCase()].FeeManager);
    }
    console.log('"FeeManager":', `"${FeeManager.target}",`);

    let TheiaRouter = evn[networkName.toUpperCase()].TheiaRouter
    if (!TheiaRouter) {
        TheiaRouter = await hre.ethers.deployContract("TheiaRouter", [evn[networkName.toUpperCase()].wNATIVE, TheiaUUIDKeeper.target, aRouterConfig.target,
        FeeManager.target, gov, evn[networkName.toUpperCase()].C3CallerProxy, signer.address, 1], feeData);
        await TheiaRouter.waitForDeployment();
    } else {
        TheiaRouter = await hre.ethers.getContractAt("TheiaRouter", evn[networkName.toUpperCase()].TheiaRouter);
    }
    console.log('"TheiaRouter":', `"${TheiaRouter.target}",`);

    let mpcaddr = "0xEef3d3678E1E739C6522EEC209Bede0197791339"
    try {
        if (chainId == 421614) {
            let artifact = await hre.artifacts.readArtifact('TheiaUUIDKeeper');
            let TheiaUUIDKeeperABI = artifact.abi
            let contract = new web3.eth.Contract(TheiaUUIDKeeperABI);
            calldata = contract.methods.addSupportedCaller(TheiaRouter.target).encodeABI()

            let govProposalData = new web3.eth.Contract(GovABI);
            console.log("SendParam proxy:", evn[networkName.toUpperCase()].C3Governor, "nonce", web3.utils.randomHex(32), "0x" +
                govProposalData.methods.genProposalData(chainId, TheiaUUIDKeeper.target, calldata).encodeABI().substring(10))
        } else {
            let isCaller = await TheiaUUIDKeeper.isSupportedCaller(TheiaRouter.target)
            console.log("TheiaUUIDKeeper.isSupportedCaller:", isCaller)
            if (!isCaller) {
                await TheiaUUIDKeeper.addSupportedCaller(TheiaRouter.target, feeData)
            }

            isCaller = await TheiaRouter.isVaildSender(mpcaddr)
            console.log("TheiaRouter.isVaildSender:", isCaller)
            if (!isCaller) {
                await TheiaRouter.addTxSender(mpcaddr, feeData)
            }
            isCaller = await FeeManager.isVaildSender(mpcaddr)
            console.log("FeeManager.isVaildSender:", isCaller)
            if (!isCaller) {
                await FeeManager.addTxSender(mpcaddr, feeData)
            }

            isCaller = await TheiaUUIDKeeper.isVaildSender(mpcaddr)
            console.log("TheiaUUIDKeeper.isVaildSender:", isCaller)
            if (!isCaller) {
                await TheiaUUIDKeeper.addTxSender(mpcaddr, feeData)
            }
            isCaller = await aRouterConfig.isVaildSender(mpcaddr)
            console.log("RouterConfig.isVaildSender:", isCaller)
            if (!isCaller) {
                await aRouterConfig.addTxSender(mpcaddr, feeData)
            }

            console.log("addTxSender", mpcaddr)
        }
    } catch (error) {
        console.log(error)
    }

    upData(networkName.toUpperCase(), {
        "FeeManager": FeeManager.target,
        "TheiaUUIDKeeper": TheiaUUIDKeeper.target,
        "TheiaRouter": TheiaRouter.target,
        "TheiaRouterConfig": aRouterConfig.target
    })

    console.log(`npx hardhat verify --network ${networkName} ${FeeManager.target} ${gov} ${evn[networkName.toUpperCase()].C3CallerProxy} ${signer.address} 1`);
    console.log(`npx hardhat verify --network ${networkName} ${aRouterConfig.target} ${gov} ${evn[networkName.toUpperCase()].C3CallerProxy} ${signer.address} 1`);
    console.log(`npx hardhat verify --network ${networkName} ${TheiaUUIDKeeper.target} ${gov} ${evn[networkName.toUpperCase()].C3CallerProxy} ${signer.address} 1`);
    console.log(`npx hardhat verify --network ${networkName} ${TheiaRouter.target} ${evn[networkName.toUpperCase()].wNATIVE} ${TheiaUUIDKeeper.target} ${aRouterConfig.target} ${FeeManager.target} ${gov} ${evn[networkName.toUpperCase()].C3CallerProxy} ${signer.address} 1`);

    await hre.run("verify:verify", {
        address: FeeManager.target,
        contract: "contracts/routerV2/FeeManager.sol:FeeManager",
        constructorArguments: [gov, evn[networkName.toUpperCase()].C3CallerProxy, signer.address, 1],
    });

    await hre.run("verify:verify", {
        address: aRouterConfig.target,
        contract: "contracts/routerV2/TheiaRouterConfig.sol:TheiaRouterConfig",
        constructorArguments: [gov, evn[networkName.toUpperCase()].C3CallerProxy, signer.address, 1],
    });

    await hre.run("verify:verify", {
        address: TheiaUUIDKeeper.target,
        contract: "contracts/routerV2/TheiaUUIDKeeper.sol:TheiaUUIDKeeper",
        constructorArguments: [gov, evn[networkName.toUpperCase()].C3CallerProxy, signer.address, 1],
    });

    await hre.run("verify:verify", {
        address: TheiaRouter.target,
        contract: "contracts/routerV2/TheiaRouter.sol:TheiaRouter",
        constructorArguments: [evn[networkName.toUpperCase()].wNATIVE, TheiaUUIDKeeper.target, aRouterConfig.target,
        FeeManager.target, gov, evn[networkName.toUpperCase()].C3CallerProxy, signer.address, 1],
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

const GovABI = [
    {
        "inputs": [
            {
                "internalType": "uint256",
                "name": "chainId",
                "type": "uint256"
            },
            {
                "internalType": "string",
                "name": "target",
                "type": "string"
            },
            {
                "internalType": "bytes",
                "name": "data",
                "type": "bytes"
            }
        ],
        "name": "genProposalData",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
]