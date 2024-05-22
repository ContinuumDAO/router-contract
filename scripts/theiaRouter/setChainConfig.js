const hre = require("hardhat");
const fs = require("fs");
const evn = require("../../output/env.json")
const { Web3 } = require('web3');

async function main() {
    const networkName = hre.network.name
    const chainId = hre.network.config.chainId
    console.log("Deploy Network name=", networkName);
    console.log("Network chain id=", chainId);

    let web3 = new Web3(Web3.givenProvider);
    const [signer] = await ethers.getSigners()
    console.log("Deploying account:", signer.address);
    console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(signer.address), "ETH"));

    let c3governor = await hre.ethers.getContractAt("contracts/protocol/C3Governor.sol:C3Governor", evn["ARB_TEST"].C3Governor);

    const chains = {}
    const chainsContents = fs.readFileSync('output/CHAIN_CONFIG.txt', 'utf-8');
    chainsContents.split(/\r?\n/).forEach(line => {
        if (line.length == 0) {
            return;
        }
        const args = JSON.parse(line);
        chains[args.chainId] = args;
        console.log("already setConfig", args.chainId, args.chain);
    });

    const allFileContents = fs.readFileSync('output/ERC20.txt', 'utf-8');
    const lines = allFileContents.split(/\r?\n/)
    for (let index = 0; index < lines.length; index++) {
        const line = lines[index];
        if (line.length == 0) {
            break
        }
        const args = JSON.parse(line);
        if (!chains[args.chainId]) {
            let govProposalData = new web3.eth.Contract(GovABI);
            let artifact = await hre.artifacts.readArtifact('TheiaRouterConfig');
            let contract = new web3.eth.Contract(artifact.abi);
            let calldata = contract.methods.setChainConfig(args.chainId, args.chain, evn[args.chain.toUpperCase()].TheiaRouter + ":v1;", "{}").encodeABI()
            let govdata = contract.methods.doGov(evn[networkName.toUpperCase()].TheiaRouterConfig, chainId + "", calldata).encodeABI()

            let sendParamsData = "0x" + govProposalData.methods.genProposalData(421614, evn["ARB_TEST"].TheiaRouterConfig, govdata).encodeABI().substring(10)
            let nonce = web3.utils.randomHex(32)
            console.log("setChainConfig:" + args.chainId, nonce, sendParamsData)

            let tx = await c3governor.sendParams(sendParamsData, nonce)
            console.log("setChainConfig:", args.chainId, args.chain, "Tx:", tx.hash);
            chains[args.chainId] = {
                chainId: args.chainId,
                networkName: args.chain,
                routerContract: evn[args.chain.toUpperCase()].TheiaRouter + ":v1;",
                extra: "{}",
                txhash: tx.hash,
            }
            fs.appendFileSync("./output/CHAIN_CONFIG.txt", JSON.stringify(chains[args.chainId]) + "\n");
        }
    }
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