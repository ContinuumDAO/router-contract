const hre = require("hardhat");
const fs = require("fs");
const evn = require("../../env.json")

const FeeTokenSymbol = "theiaUSDT"
const fee = 500

async function main() {
    const networkName = hre.network.name
    const chainId = hre.network.config.chainId
    console.log("Deploy Network name=", networkName);
    console.log("Network chain id=", chainId);

    const [signer] = await ethers.getSigners()
    console.log("Deploying account:", signer.address);
    console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(signer.address), "ETH"));

    const TheiaRouter = await hre.ethers.getContractAt("TheiaRouter", evn[networkName.toUpperCase()].TheiaRouter);
    console.log("TheiaRouter address:", TheiaRouter.target);

    const tokens = {}
    const tokensContents = fs.readFileSync('FEE_CONFIG.txt', 'utf-8');
    tokensContents.split(/\r?\n/).forEach(line => {
        if (line.length == 0) {
            return;
        }
        const args = JSON.parse(line);
        if (!tokens[args.name]) {
            tokens[args.name] = {}
        }
        if (args.chainId == chainId) {
            tokens[args.name][args.chainId] = args;
            console.log("already setConfig", args.name, args.chain, args.chainId);
        }
    });

    const allFileContents = fs.readFileSync('ERC20.txt', 'utf-8');
    const lines = allFileContents.split(/\r?\n/)
    for (let index = 0; index < lines.length; index++) {
        const line = lines[index];
        if (line.length == 0) {
            break
        }
        const args = JSON.parse(line);
        if (args.name != FeeTokenSymbol || args.chainId != chainId) {
            continue
        }
        if (!tokens[args.name] || !tokens[args.name][args.chainId]) {
            let feeToken = args.underlying
            if (feeToken == "0x0000000000000000000000000000000000000000") {
                feeToken = args.address
            }
            await TheiaRouter.connect(signer).addFeeToken(feeToken)
            await sleep(20000)
            let tx = await TheiaRouter.connect(signer).setFeeConfig(args.chainId, 1, 1, [feeToken], [fee])
            console.log("setFeeConfig:", args.name, args.chain, args.chainId, feeToken, "Tx:", tx.hash);
            if (!tokens[args.name]) {
                tokens[args.name] = {}
            }
            tokens[args.name][args.chainId] = {
                name: args.name,
                chain: args.chain,
                chainId: args.chainId,
                feeToken: feeToken,
                fee: fee,
                tx: tx.hash
            }
            fs.appendFileSync("FEE_CONFIG.txt", JSON.stringify(tokens[args.name][args.chainId]) + "\n");
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
