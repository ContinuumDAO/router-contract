const hre = require("hardhat");
const fs = require("fs");
const evn = require("../../env.json")

async function main() {
    const networkName = hre.network.name.toUpperCase()
    const chainId = hre.network.config.chainId
    console.log("Deploy Network name=", networkName);
    console.log("Network chain id=", chainId);

    const [signer] = await ethers.getSigners()
    console.log("Deploying account:", signer.address);
    console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(signer.address), "ETH"));

    const aRouterConfig = await hre.ethers.getContractAt("TheiaRouterConfig", evn[networkName].TheiaRouterConfig);
    console.log("TheiaRouterConfig address:", aRouterConfig.target);

    const tokens = {}
    const tokensContents = fs.readFileSync('TOKEN_CONFIG.txt', 'utf-8');
    tokensContents.split(/\r?\n/).forEach(line => {
        if (line.length == 0) {
            return;
        }
        const args = JSON.parse(line);
        if (!tokens[args.name]) {
            tokens[args.name] = {}
        }
        if (args.execChain == networkName) {
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
        if (!tokens[args.symbol] || !tokens[args.symbol][args.chainId]) {
            let extra = "{\"underlying\":\"" + args.underlying + "\"}"
            let tx = await aRouterConfig.connect(signer).setTokenConfig(args.symbol, args.chainId, args.address, args.decimals, 1,
                args.router, extra)
            console.log("setTokenConfig:", args.symbol, args.chain, args.chainId, "Tx:", tx.hash);
            if (!tokens[args.symbol]) {
                tokens[args.symbol] = {}
            }
            tokens[args.symbol][args.chainId] = {
                name: args.symbol,
                execChain: networkName,
                chain: args.chain,
                chainId: args.chainId,
                address: args.address,
                decimals: args.decimals,
                version: 1,
                router: args.router,
                extra: extra,
                tx: tx.hash
            }
            fs.appendFileSync("TOKEN_CONFIG.txt", JSON.stringify(tokens[args.symbol][args.chainId]) + "\n");
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
