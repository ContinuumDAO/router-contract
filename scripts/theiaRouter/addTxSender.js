const hre = require("hardhat");
const fs = require("fs");
const evn = require("../../output/env.json")
const { Web3 } = require('web3');

let ARB = 421614
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
    console.log("c3governor address:", c3governor.target);

    let contract_names = ["FeeManager", "TheiaUUIDKeeper", "TheiaRouter", "TheiaRouterConfig"]
    let govProposalData = new web3.eth.Contract(GovABI);
    for (let index = 0; index < contract_names.length; index++) {
        let name = contract_names[index];
        let artifact = await hre.artifacts.readArtifact(name);
        let contract = new web3.eth.Contract(artifact.abi);
        let calldata = contract.methods.addTxSender("0xEef3d3678E1E739C6522EEC209Bede0197791339").encodeABI()
        if (chainId != ARB) {
            calldata = contract.methods.doGov(evn[networkName.toUpperCase()][name], chainId + "", calldata).encodeABI()
        }
        console.log(name, evn[networkName.toUpperCase()][name])
        let sendParamsData = "0x" + govProposalData.methods.genProposalData(ARB, evn["ARB_TEST"][name], calldata).encodeABI().substring(10)
        let nonce = web3.utils.randomHex(32)

        let tx = await c3governor.connect(signer).sendParams(sendParamsData, nonce)
        console.log("setChainConfig:" + chainId, tx.hash)
        await sleep(500)
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