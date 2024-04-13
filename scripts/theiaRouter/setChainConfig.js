const hre = require("hardhat");
const fs = require("fs");
const evn = require("../../env.json")

async function main() {
    const networkName = hre.network.name
    const chainId = hre.network.config.chainId
    console.log("Deploy Network name=", networkName);
    console.log("Network chain id=", chainId);

    const [signer] = await ethers.getSigners()
    console.log("Deploying account:", signer.address);
    console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(signer.address), "ETH"));

    const aRouterConfig = await hre.ethers.getContractAt("TheiaRouterConfig", evn[networkName.toUpperCase()].TheiaRouterConfig);
    console.log("TheiaRouterConfig address:", aRouterConfig.target);

    const chains = {}
    const chainsContents = fs.readFileSync('CHAIN_CONFIG.txt', 'utf-8');
    chainsContents.split(/\r?\n/).forEach(line => {
        if (line.length == 0) {
            return;
        }
        const args = JSON.parse(line);
        chains[args.chainId] = args;
        console.log("already setConfig", args.chainId, args.chain);
    });

    const allFileContents = fs.readFileSync('ERC20.txt', 'utf-8');
    const lines = allFileContents.split(/\r?\n/)
    for (let index = 0; index < lines.length; index++) {
        const line = lines[index];
        if (line.length == 0) {
            break
        }
        const args = JSON.parse(line);
        if (!chains[args.chainId]) {
            let tx = await aRouterConfig.setChainConfig(args.chainId, args.chain, evn[args.chain.toUpperCase()].TheiaRouter + ":v1;", "{}")
            console.log("setChainConfig:", args.chainId, args.chain, "Tx:", tx.hash);
            chains[args.chainId] = {
                chainId: args.chainId,
                networkName: args.chain,
                routerContract: evn[args.chain.toUpperCase()].TheiaRouter + ":v1;",
                extra: "{}",
                txhash: tx.hash,
            }
            fs.appendFileSync("CHAIN_CONFIG.txt", JSON.stringify(chains[args.chainId]) + "\n");
        }
    }
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
