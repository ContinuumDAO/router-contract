const hre = require("hardhat");
const evn = require("../../env.json")

async function main() {
    const networkName = hre.network.name
    const chainId = hre.network.config.chainId
    console.log("Deploy Network name=", networkName);
    console.log("Network chain id=", chainId);

    console.log("wNATIVE", evn[networkName.toUpperCase()].wNATIVE);

    const [signer] = await ethers.getSigners()
    console.log("Deploying account:", signer.address);
    console.log("Account balance:", ethers.formatEther(await ethers.provider.getBalance(signer.address), "ETH"));

    const c3SwapIDKeeper = await hre.ethers.getContractAt("contracts/protocol/C3SwapIDKeeper.sol:C3SwapIDKeeper", evn[networkName.toUpperCase()].C3SwapIDKeeper);
    const c3Caller = await hre.ethers.getContractAt("contracts/protocol/C3Caller.sol:C3Caller", evn[networkName.toUpperCase()].C3Caller);
    const C3DappManager = await hre.ethers.getContractAt("C3DappManager", evn[networkName.toUpperCase()].C3DappManager);
    const c3CallerProxy = await hre.ethers.getContractAt("C3CallerProxy", evn[networkName.toUpperCase()].C3CallerProxy);

    console.log('"C3SwapIDKeeper":', `"${c3SwapIDKeeper.target}",`);
    console.log('"C3Caller":', `"${c3Caller.target}",`);
    console.log('"C3DappManager":', `"${C3DappManager.target}",`);
    console.log('"C3CallerProxy":', `"${c3CallerProxy.target}",`);

    const currentImplAddress = await hre.upgrades.erc1967.getImplementationAddress(c3CallerProxy.target);
    console.log('"C3CallerProxyImp":', `"${currentImplAddress}",`);

    console.log(`npx hardhat verify --network ${networkName} ${c3SwapIDKeeper.target} ${signer.address}`);
    console.log(`npx hardhat verify --network ${networkName} ${c3Caller.target} ${signer.address} ${c3SwapIDKeeper.target}`);
    console.log(`npx hardhat verify --network ${networkName} ${C3DappManager.target} ${signer.address}`);
    console.log(`npx hardhat verify --network ${networkName} ${currentImplAddress} ${signer.address}`);

    await hre.run("verify:verify", {
        address: c3SwapIDKeeper.target,
        contract: "contracts/protocol/C3SwapIDKeeper.sol:C3SwapIDKeeper",
        constructorArguments: [evn[networkName.toUpperCase()].MPC],
    });

    await hre.run("verify:verify", {
        address: c3Caller.target,
        contract: "contracts/protocol/C3Caller.sol:C3Caller",
        constructorArguments: [evn[networkName.toUpperCase()].MPC, c3SwapIDKeeper.target],
    });

    await hre.run("verify:verify", {
        address: C3DappManager.target,
        contract: "contracts/protocol/C3DappManager.sol:C3DappManager",
        constructorArguments: [evn[networkName.toUpperCase()].MPC],
    });

    await hre.run("verify:verify", {
        address: currentImplAddress,
        contract: "contracts/protocol/C3CallerProxy.sol:C3CallerProxy",
        constructorArguments: [],
    });
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
