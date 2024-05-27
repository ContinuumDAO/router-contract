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

    const [signer] = await ethers.getSigners()
    console.log("Deploying account:", signer.address);
    console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(signer.address), "ETH"));

    let gov = signer.address;
    if (chainId == 421614) {
        gov = evn[networkName.toUpperCase()].C3Governor
    }

    let aRouterConfig = evn[networkName.toUpperCase()].TheiaRouterConfig
    if (!aRouterConfig) {
        aRouterConfig = await hre.ethers.deployContract("TheiaRouterConfig", [gov, evn[networkName.toUpperCase()].C3CallerProxy, signer.address, 1]);
        await aRouterConfig.waitForDeployment();
    } else {
        aRouterConfig = await hre.ethers.getContractAt("TheiaRouterConfig", evn[networkName.toUpperCase()].TheiaRouterConfig);
    }
    console.log('"TheiaRouterConfig":', `"${aRouterConfig.target}",`);

    let TheiaSwapIDKeeper = evn[networkName.toUpperCase()].TheiaSwapIDKeeper
    if (!TheiaSwapIDKeeper) {
        TheiaSwapIDKeeper = await hre.ethers.deployContract("TheiaUUIDKeeper", [gov, evn[networkName.toUpperCase()].C3CallerProxy, signer.address, 1]);
        await TheiaSwapIDKeeper.waitForDeployment();
    } else {
        TheiaSwapIDKeeper = await hre.ethers.getContractAt("TheiaUUIDKeeper", evn[networkName.toUpperCase()].TheiaSwapIDKeeper);
    }
    console.log('"TheiaSwapIDKeeper":', `"${TheiaSwapIDKeeper.target}",`);

    let FeeManager = evn[networkName.toUpperCase()].FeeManager
    if (!FeeManager) {
        FeeManager = await hre.ethers.deployContract("FeeManager", [gov, evn[networkName.toUpperCase()].C3CallerProxy, signer.address, 1]);
        await FeeManager.waitForDeployment();
    } else {
        FeeManager = await hre.ethers.getContractAt("FeeManager", evn[networkName.toUpperCase()].FeeManager);
    }
    console.log('"FeeManager":', `"${FeeManager.target}",`);

    let TheiaRouter = evn[networkName.toUpperCase()].TheiaRouter
    if (!TheiaRouter) {
        TheiaRouter = await hre.ethers.deployContract("TheiaRouter", [evn[networkName.toUpperCase()].wNATIVE, TheiaSwapIDKeeper.target, aRouterConfig.target,
        FeeManager.target, gov, evn[networkName.toUpperCase()].C3CallerProxy, signer.address, 1]);
        await TheiaRouter.waitForDeployment();
    } else {
        TheiaRouter = await hre.ethers.getContractAt("TheiaRouter", evn[networkName.toUpperCase()].TheiaRouter);
    }
    console.log('"TheiaRouter":', `"${TheiaRouter.target}",`);

    try {
        if (chainId == 421614) {
            let artifact = await hre.artifacts.readArtifact('TheiaUUIDKeeper');
            TheiaUUIDKeeperABI = artifact.abi
            let contract = new web3.eth.Contract(TheiaUUIDKeeperABI);
            calldata = contract.methods.addSupportedCaller(TheiaRouter.target).encodeABI()

            let govProposalData = new web3.eth.Contract(GovABI);
            console.log("SendParam proxy:", evn[networkName.toUpperCase()].C3Governor, "nonce", web3.utils.randomHex(32), "0x" +
                govProposalData.methods.genProposalData(chainId, TheiaSwapIDKeeper.target, calldata).encodeABI().substring(10))
        } else {
            await TheiaSwapIDKeeper.addSupportedCaller(TheiaRouter.target)

            await TheiaRouter.addTxSender("0xEef3d3678E1E739C6522EEC209Bede0197791339")
            await FeeManager.addTxSender("0xEef3d3678E1E739C6522EEC209Bede0197791339")
            await TheiaSwapIDKeeper.addTxSender("0xEef3d3678E1E739C6522EEC209Bede0197791339")
            await aRouterConfig.addTxSender("0xEef3d3678E1E739C6522EEC209Bede0197791339")

            console.log("addTxSender", "0xEef3d3678E1E739C6522EEC209Bede0197791339")
        }
    } catch (error) {
        console.log(error)
    }

    upData(networkName.toUpperCase(), {
        "FeeManager": FeeManager.target,
        "TheiaSwapIDKeeper": TheiaSwapIDKeeper.target,
        "TheiaRouter": TheiaRouter.target,
        "TheiaRouterConfig": aRouterConfig.target
    })

    console.log(`npx hardhat verify --network ${networkName} ${FeeManager.target} ${gov} ${evn[networkName.toUpperCase()].C3CallerProxy} ${signer.address} 1`);
    console.log(`npx hardhat verify --network ${networkName} ${aRouterConfig.target} ${gov} ${evn[networkName.toUpperCase()].C3CallerProxy} ${signer.address} 1`);
    console.log(`npx hardhat verify --network ${networkName} ${TheiaSwapIDKeeper.target} ${gov} ${evn[networkName.toUpperCase()].C3CallerProxy} ${signer.address} 1`);
    console.log(`npx hardhat verify --network ${networkName} ${TheiaRouter.target} ${evn[networkName.toUpperCase()].wNATIVE} ${TheiaSwapIDKeeper.target} ${aRouterConfig.target} ${FeeManager.target} ${gov} ${evn[networkName.toUpperCase()].C3CallerProxy} ${signer.address} 1`);

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
        address: TheiaSwapIDKeeper.target,
        contract: "contracts/routerV2/TheiaUUIDKeeper.sol:TheiaUUIDKeeper",
        constructorArguments: [gov, evn[networkName.toUpperCase()].C3CallerProxy, signer.address, 1],
    });

    await hre.run("verify:verify", {
        address: TheiaRouter.target,
        contract: "contracts/routerV2/TheiaRouter.sol:TheiaRouter",
        constructorArguments: [evn[networkName.toUpperCase()].wNATIVE, TheiaSwapIDKeeper.target, aRouterConfig.target,
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