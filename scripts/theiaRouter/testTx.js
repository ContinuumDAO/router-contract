const hre = require("hardhat");

const evn = require("../../env.json")

async function main() {
    const networkName = hre.network.name
    const chainId = hre.network.config.chainId
    console.log("Deploy Network name=", networkName);
    console.log("Network chain id=", chainId);

    const [signer] = await ethers.getSigners()
    console.log("Deploying account:", signer.address);
    console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(signer.address), "ETH"));

    const theiaRouter = await hre.ethers.getContractAt("TheiaRouter", evn[networkName.toUpperCase()].TheiaRouter);

    console.log('"TheiaRouter":', `"${theiaRouter.target}",`);


    var tGoUSDC = "0xC3EBfe89CA9bA92BCe5979f92BE18bc5b020F96c"
    var bnbRouter = "0x0B20BcE7b95B0559FFf8c17E83c49FcEf4458b4A"

    var tBnbUSDC = "0x27054383dF53DCB8f62eF1B84F479473edd8D5B6"

    let tx = await theiaRouter.connect(signer).swapOutAuto(tGoUSDC,"100000",bnbRouter, signer.address, tBnbUSDC, "97")
    console.log("Tx:", tx.hash);

    // npx hardhat run scripts/theiaRouter/testTx.js --network goerli

}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
