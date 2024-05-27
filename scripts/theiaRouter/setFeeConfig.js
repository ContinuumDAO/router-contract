const hre = require("hardhat");
const fs = require("fs");
const evn = require("../../output/env.json")
const { Web3 } = require('web3');

const FeeTokenName = "theiaUSDT"

const fee = 200
const ARB = 421614

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

    const tokens = {}
    const tokensContents = fs.readFileSync('output/FEE_CONFIG.txt', 'utf-8');
    tokensContents.split(/\r?\n/).forEach(line => {
        if (line.length == 0) {
            return;
        }
        const args = JSON.parse(line);
        if (!tokens[args.name]) {
            tokens[args.name] = {}
        }
        tokens[args.name][args.chainId] = args;
        console.log("already setConfig", args.name, args.chain, args.chainId);
    });

    const allFileContents = fs.readFileSync('output/ERC20.txt', 'utf-8');
    const lines = allFileContents.split(/\r?\n/)
    for (let index = 0; index < lines.length; index++) {
        const line = lines[index];
        if (line.length == 0) {
            break
        }
        const args = JSON.parse(line);
        if (args.name != FeeTokenName) {
            continue
        }
        if (!tokens[args.name] || !tokens[args.name][args.chainId]) {
            // let feeToken = args.underlying
            // if (feeToken == "0x0000000000000000000000000000000000000000") {
            //     feeToken = args.address
            // }
            let feeToken = args.address

            let govProposalData = new web3.eth.Contract(GovABI);
            let artifact = await hre.artifacts.readArtifact('FeeManager');
            let contract = new web3.eth.Contract(artifact.abi);
            let calldata = contract.methods.addFeeToken(feeToken).encodeABI()
            if (args.chainId != ARB) {
                calldata = contract.methods.doGov(evn[args.chain].FeeManager, args.chainId + "", calldata).encodeABI()
            }
            let sendParamsData = "0x" + govProposalData.methods.genProposalData(ARB, evn["ARB_TEST"].FeeManager, calldata).encodeABI().substring(10)
            let nonce = web3.utils.randomHex(32)
            console.log("addFeeToken to " + args.chainId, nonce, sendParamsData)
            let tx1 = await c3governor.connect(signer).sendParams(sendParamsData, nonce)
            await sleep(5000)

            calldata = contract.methods.setFeeConfig(args.chainId, 0, 1, [feeToken], [fee]).encodeABI()
            if (args.chainId != ARB) {
                calldata = contract.methods.doGov(evn[args.chain].FeeManager, args.chainId + "", calldata).encodeABI()
            }

            sendParamsData = "0x" + govProposalData.methods.genProposalData(ARB, evn["ARB_TEST"].FeeManager, calldata).encodeABI().substring(10)
            nonce = web3.utils.randomHex(32)
            console.log("setFeeConfig to " + args.chainId, nonce, sendParamsData)

            let tx2 = await c3governor.connect(signer).sendParams(sendParamsData, nonce)
            if (!tokens[args.name]) {
                tokens[args.name] = {}
            }
            tokens[args.name][args.chainId] = {
                name: args.name,
                chain: args.chain,
                chainId: args.chainId,
                feeToken: feeToken,
                fee: fee,
                tx: tx1.hash + "," + tx2.hash
            }
            fs.appendFileSync("output/FEE_CONFIG.txt", JSON.stringify(tokens[args.name][args.chainId]) + "\n");
            await sleep(5000)
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