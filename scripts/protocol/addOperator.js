const hre = require("hardhat");
const evn = require("../../output/env.json")

async function main() {
    const networkName = hre.network.name
    const chainId = hre.network.config.chainId
    console.log("Deploy Network name=", networkName);
    console.log("Network chain id=", chainId);

    const [signer] = await ethers.getSigners()
    console.log("Deploying account:", signer.address);
    console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(signer.address), "ETH"));

    // const c3SwapIDKeeper = await hre.ethers.getContractAt("C3UUIDKeeper", evn[networkName.toUpperCase()].C3UUIDKeeper);
    // const c3Caller = await hre.ethers.getContractAt("contracts/protocol/C3Caller.sol:C3Caller", evn[networkName.toUpperCase()].C3Caller);
    // const C3DappManager = await hre.ethers.getContractAt("C3DappManager", evn[networkName.toUpperCase()].C3DappManager);
    const c3CallerProxy = await hre.ethers.getContractAt("C3CallerProxy", evn[networkName.toUpperCase()].C3CallerProxy);
    const c3Governor = await hre.ethers.getContractAt("contracts/protocol/C3Governor.sol:C3Governor", evn[networkName.toUpperCase()].C3Governor);

    console.log(c3CallerProxy.target, c3Governor.target);

    // for estimate gas
    // "0xEef3d3678E1E739C6522EEC209Bede0197791339"
    // await c3CallerProxy.addOperator(c3Governor.target)
    // for real call
    // await c3Caller.addOperator(op)

    // console.log("c3Caller getAllOperators:", await c3Caller.getAllOperators());
    console.log("C3CallerProxy getAllOperators:", await c3CallerProxy.getAllOperators());

}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
