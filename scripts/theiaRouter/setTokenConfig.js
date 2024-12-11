const hre = require("hardhat");
const fs = require("fs");
const evn = require("../../output/env.json")
const { Web3 } = require('web3');
const ARB = 421614
async function main() {
    const networkName = hre.network.name.toUpperCase()
    const chainId = hre.network.config.chainId
    console.log("Deploy Network name=", networkName);
    console.log("Network chain id=", chainId);

    let web3 = new Web3(Web3.givenProvider);
    const [signer] = await ethers.getSigners()
    console.log("Deploying account:", signer.address);
    console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(signer.address), "ETH"));

    // const aRouterConfig = await hre.ethers.getContractAt("TheiaRouterConfig", evn[networkName].TheiaRouterConfig);

    let c3governor = await hre.ethers.getContractAt("contracts/protocol/C3Governor.sol:C3Governor", evn["ARB_TEST"].C3Governor);
    console.log("c3governor address:", c3governor.target);

    const chainList = {}
    const tokens = {}
    const tokensContents = fs.readFileSync('output/TOKEN_CONFIG.txt', 'utf-8');
    tokensContents.split(/\r?\n/).forEach(line => {
        if (line.length == 0) {
            return;
        }
        const args = JSON.parse(line);
        let key = args.name + "-" + args.chainId
        if (!tokens[key]) {
            tokens[key] = {}
        }
        // if (args.execChain == networkName) {
        tokens[key][args.execChain] = args;
        console.log("set key:", key, args.execChain)
        // }
    });

    const allFileContents = fs.readFileSync('output/ERC20.txt', 'utf-8');
    const lines = allFileContents.split(/\r?\n/)

    for (let index = 0; index < lines.length; index++) {
        const line = lines[index];
        if (line.length == 0) {
            break
        }
        const args = JSON.parse(line);
        chainList[args.chainId] = args.chain;
    }
    for (let index = 0; index < lines.length; index++) {
        const line = lines[index];
        if (line.length == 0) {
            break
        }
        const args = JSON.parse(line);
        let key = args.symbol + "-" + args.chainId

        for (let targetChainId in chainList) {
            let targetChain = chainList[targetChainId];
            if (!tokens[key] || !tokens[key][targetChain]) {
                if (!evn[targetChain] || !evn[targetChain].TheiaRouterConfig) {
                    console.log("targetChain ", targetChain, "TheiaRouterConfig is missing")
                    continue
                }
                console.log("setTokenConfig:", args.symbol, args.chain, args.chainId, "to", targetChain, targetChainId)
                let extra = "{\"underlying\":\"" + args.underlying + "\"}"
                let govProposalData = new web3.eth.Contract(GovABI);
                let artifact = await hre.artifacts.readArtifact('TheiaRouterConfig');
                let contract = new web3.eth.Contract(artifact.abi);
                let calldata = contract.methods.setTokenConfig(args.symbol, args.chainId, args.address, args.decimals, 1,
                    args.router, extra).encodeABI()
                if (targetChainId != ARB) {
                    calldata = contract.methods.doGov(evn[targetChain].TheiaRouterConfig, targetChainId + "", calldata).encodeABI()
                }
                let sendParamsData = "0x" + govProposalData.methods.genProposalData(ARB, evn["ARB_TEST"].TheiaRouterConfig, calldata).encodeABI().substring(10)
                let nonce = web3.utils.randomHex(32)
                console.log("param:", nonce, sendParamsData)

                let tx = await c3governor.connect(signer).sendParams(sendParamsData, nonce)
                if (!tokens[key]) {
                    tokens[key] = {}
                }
                tokens[key][targetChain] = {
                    name: args.symbol,
                    execChain: targetChain,
                    chain: args.chain,
                    chainId: args.chainId,
                    address: args.address,
                    decimals: args.decimals,
                    version: 1,
                    router: args.router,
                    extra: extra,
                    tx: tx.hash
                }
                fs.appendFileSync("output/TOKEN_CONFIG.txt", JSON.stringify(tokens[key][targetChain]) + "\n");
                await sleep(5000)
            } else {
                console.log("already setConfig", args.name, args.chain, args.chainId, "to", targetChain);
            }
        }

    }
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms))
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

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