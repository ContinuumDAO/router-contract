const { expect } = require("chai");
const { Web3 } = require('web3');
let web3 = new Web3(Web3.givenProvider);
const BN = require('bn.js');

describe("TheiaRouter", function () {
    let routerV2
    let erc20Token, underlyingToken, theiaToken
    let weth, usdc
    let owner
    let otherAccount
    let chainID
    let swapIDKeeper, theiaCallData
    let c3SwapIDKeeper, c3CallerProxy, c3Caller
    let theiaRouterConfig
    let result_success = "0x0000000000000000000000000000000000000000000000000000000000000001"


    // async function deployRouterV2() {
    //     // Contracts are deployed using the first signer/account by default
    //     const [_owner, _otherAccount] = await ethers.getSigners();
    //     const WETH = await ethers.getContractFactory("WETH");
    //     weth = await WETH.deploy();

    //     const TheiaCallData = await ethers.getContractFactory("TheiaCallData");
    //     theiaCallData = await TheiaCallData.deploy();

    //     const TheiaSwapIDKeeper = await ethers.getContractFactory("TheiaSwapIDKeeper");
    //     swapIDKeeper = await TheiaSwapIDKeeper.deploy(_owner);

    //     const TheiaRouterConfig = await ethers.getContractFactory("TheiaRouterConfig");
    //     theiaRouterConfig = await TheiaRouterConfig.deploy(c3CallerProxy.target, 1);

    //     const TheiaRouter = await ethers.getContractFactory("TheiaRouter");
    //     routerV2 = await TheiaRouter.deploy(weth.target, swapIDKeeper.target, theiaRouterConfig.target, usdc.target,
    //         _owner.address, c3CallerProxy.target, 1);

    //     await swapIDKeeper.addSupportedCaller(routerV2.target)

    //     owner = _owner
    //     otherAccount = _otherAccount
    //     chainID = await routerV2.cID();
    // }


    // async function deployC3Caller() {
    //     // Contracts are deployed using the first signer/account by default
    //     const [_owner, _otherAccount] = await ethers.getSigners();

    //     const C3SwapIDKeeper = await ethers.getContractFactory("contracts/protocol/C3UUIDKeeper.sol:C3UUIDKeeper");
    //     c3SwapIDKeeper = await C3SwapIDKeeper.deploy(_owner.address);

    //     const C3Caller = await ethers.getContractFactory("contracts/protocol/C3Caller.sol:C3Caller");
    //     c3Caller = await C3Caller.deploy(_owner.address, c3SwapIDKeeper.target);

    //     const C3CallerProxy = await ethers.getContractFactory("C3CallerProxy");
    //     // c3CallerProxy = await C3CallerProxy.deploy(_owner.address, c3Caller.target);
    //     c3CallerProxy = await upgrades.deployProxy(C3CallerProxy, [_owner.address, c3Caller.target], { initializer: 'initialize', kind: 'uups' });

    //     await c3SwapIDKeeper.addSupportedCaller(c3Caller.target)

    //     await c3Caller.addOperator(c3CallerProxy.target)

    //     const USDC = await ethers.getContractFactory("USDC");
    //     usdc = await USDC.deploy();
    // }

    async function deployC3ERC20(name, symbol, decimals, underlying, vault) {
        // Contracts are deployed using the first signer/account by default
        const [_owner, _otherAccount] = await ethers.getSigners();
        const TheiaERC20 = await ethers.getContractFactory("TestTheiaERC20");
        return await TheiaERC20.deploy(name, symbol, decimals, underlying, vault);
    }

    function demoXCallData(amount) {
        let ABI = [{
            "inputs": [
                {
                    "internalType": "uint256",
                    "name": "x",
                    "type": "uint256"
                }
            ],
            "name": "setX",
            "outputs": [],
            "stateMutability": "payable",
            "type": "function"
        }]
        let contract = new web3.eth.Contract(ABI);
        return contract.methods.setX(amount).encodeABI()
    }


    beforeEach(async () => {
        // await deployC3Caller()
        // await deployRouterV2()
        // erc20Token = await deployC3ERC20("theiaETH", "theiaETH", 18, weth.target, routerV2.target)
        // underlyingToken = await deployC3ERC20("theiaUSDC", "theiaUSDC", 6, usdc.target, routerV2.target)
        // theiaToken = await deployC3ERC20("theiaToken", "theiaToken", 18, "0x0000000000000000000000000000000000000000", owner.address)
        // // await theiaToken.initVault(routerV2.target)

        // await theiaToken.setDelay(0)
        // await theiaToken.setMinter(routerV2.target)
        // await theiaToken.applyMinter()
    })

    // async function registerAAA() {
    //     await theiaRouterConfig.setTokenConfig("AAA", 250, theiaToken.target, 18, 1, routerV2.target, "0x0000000000000000000000000000000000000000")
    //     await theiaRouterConfig.setTokenConfig("AAA", chainID, theiaToken.target, 18, 1, routerV2.target, "0x0000000000000000000000000000000000000000")
    // }



    // describe("TheiaERC20", function () {
    //     it("Deploy", async function () {
    //         expect(await erc20Token.owner()).to.equal(routerV2.target)

    //         expect(await routerV2.gov()).to.equal(owner.address)
    //     });
    // });

    // describe("TheiaRouterConfig", function () {
    //     it("add del", async function () {
    //         await expect(routerV2.addFeeToken(usdc.target)).to.emit(routerV2, "AddFeeToken").withArgs(usdc.target)

    //         await expect(routerV2.delFeeToken(usdc.target)).to.emit(routerV2, "DelFeeToken").withArgs(usdc.target)
    //     });

    //     it("setFeeConfig", async function () {
    //         await routerV2.setFeeConfig(chainID, 0, 1, [usdc.target], [500])

    //         expect(await routerV2.getFeeConfig(1, 250, usdc.target)).to.equal(0)

    //         expect(await routerV2.getFeeConfig(chainID, 250, usdc.target)).to.equal(500)
    //     });
    // });

    // describe("TheiaRouter", function () {
    //     it("convertDecimals", async function () {
    //         let amount = web3.utils.toNumber("1000000000000000000")
    //         expect(await routerV2.convertDecimals(amount, 18, 18)).to.equal(amount)

    //         expect(await routerV2.convertDecimals(amount, 18, 6)).to.equal("1000000")

    //         expect(await routerV2.convertDecimals("1000000", 6, 18)).to.equal(amount)

    //         expect(await routerV2.convertDecimals("1000000", 6, 0)).to.equal("1")

    //         expect(await routerV2.convertDecimals("1000000", 10, 8)).to.equal("10000")

    //         expect(await routerV2.convertDecimals("1000", 10, 5)).to.equal("0")
    //     });
    //     it("SwapOut", async function () {
    //         expect(await theiaToken.isMinter(routerV2.target)).to.equal(true)
    //         let amount = web3.utils.toNumber("1000000000000000000")

    //         await theiaToken.mint(otherAccount.address, amount)
    //         expect(await theiaToken.balanceOf(otherAccount.address)).to.equal(amount)

    //         let swapID = await swapIDKeeper.calcSwapID(routerV2.target, theiaToken.target, otherAccount.address, amount.toString(), otherAccount.address, "250")
    //         let calldata = await theiaCallData.genSwapInAutoCallData(theiaToken.target, amount.toString(), otherAccount.address, swapID, 18, theiaToken.target)

    //         // routerV2.target solidity string is different from calldata string
    //         // let encodedata = await c3SwapIDKeeper.calcCallerEncode(c3Caller.target, "1", routerV2.target.toLowerCase(), "250", calldata)
    //         let uuid = await c3SwapIDKeeper.calcCallerUUID(c3Caller.target, "1", routerV2.target.toLowerCase(), "250", calldata)
    //         // console.log(uuid, web3.utils.toHex(250), routerV2.target)

    //         await expect(routerV2.connect(otherAccount).swapOutAuto("AAA", amount.toString(), routerV2.target, otherAccount.address, usdc.target, 250))
    //             .to.revertedWith("TR:token not support")

    //         await registerAAA()

    //         await usdc.transfer(otherAccount, 5000000)
    //         expect(await usdc.balanceOf(otherAccount.address)).to.equal(5000000)
    //         await usdc.connect(otherAccount).approve(routerV2, 5000000)

    //         await routerV2.setFeeConfig(chainID, 0, 1, [usdc.target], [500])

    //         // console.log(await routerV2.queryFee(usdc.target, 250))

    //         await theiaToken.connect(otherAccount).approve(routerV2.target, amount)

    //         await expect(routerV2.connect(otherAccount).swapOutAuto("AAA", amount.toString(), routerV2.target, otherAccount.address, usdc.target, 250))
    //             .to.emit(routerV2, "LogSwapOut").withArgs(theiaToken.target, otherAccount.address, otherAccount.address.toString().toLowerCase(), amount.toString(), chainID, 250, 5000000, swapID, calldata)
    //             .to.emit(c3Caller, "LogC3Call").withArgs("1", uuid, routerV2.target, "250", routerV2.target.toLowerCase(), calldata)

    //         expect(await usdc.balanceOf(otherAccount.address)).to.equal(0)
    //         expect(await usdc.balanceOf(routerV2.target)).to.equal(5000000)

    //         await expect(c3CallerProxy.execute("1", uuid, routerV2.target, chainID.toString(), "sourceTxHash", routerV2.target, calldata))
    //             .to.emit(c3Caller, "LogExecCall").withArgs("1", routerV2.target, true, uuid, chainID, "sourceTxHash", calldata, result_success)
    //             .to.emit(routerV2, "LogSwapIn").withArgs(theiaToken.target, otherAccount.address, swapID, amount.toString(), chainID, chainID, "sourceTxHash")

    //     });

    //     it("Fallback", async function () {
    //         let amount = web3.utils.toNumber("1000000000000000000")
    //         await theiaToken.mint(otherAccount.address, amount)

    //         let swapID = await swapIDKeeper.calcSwapID(routerV2.target, theiaToken.target, otherAccount.address, amount.toString(), otherAccount.address, "250")
    //         let calldata = await theiaCallData.genSwapInAutoCallData(theiaToken.target, amount.toString(), otherAccount.address, swapID, 18, theiaToken.target)

    //         await registerAAA()

    //         await expect(routerV2.connect(otherAccount).swapOutAuto("AAA", amount.toString(), routerV2.target, otherAccount.address, usdc.target, 250))
    //             .to.emit(routerV2, "LogSwapOut").withArgs(theiaToken.target, otherAccount.address, otherAccount.address.toString().toLowerCase(), amount.toString(), chainID, 250, 0, swapID, calldata)

    //         let uuid = await c3SwapIDKeeper.calcCallerUUID(c3Caller.target, "1", theiaToken.target.toLowerCase(), "250", calldata)
    //         let fallbackdata = "0xb121f51d00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000000c4" + calldata.substring(2) + "000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
    //         // call the wrong to contract
    //         await expect(c3CallerProxy.execute("2", uuid, routerV2.target, chainID.toString(), "sourceTxHash", fallbackdata, calldata))
    //             .to.rejectedWith("C3Caller: dappID dismatch");

    //         await expect(c3CallerProxy.c3Fallback("1", uuid, routerV2.target, chainID.toString(), "failTxHash", fallbackdata, "0x"))
    //             .to.emit(c3Caller, "LogExecFallback").withArgs("1", routerV2.target, true, uuid, chainID, "failTxHash", "0x", fallbackdata, result_success)
    //             .emit(routerV2, "LogSwapFallback").withArgs(swapID, theiaToken.target, otherAccount.address, amount.toString(), "0x04b97db9", "0x" + calldata.substring(10), "0x")


    //     });

        // it("swapOutAuto Underlying", async function () {
        //     let amount = web3.utils.toNumber("1000000000000000000")

        //     await usdc.approve(routerV2.target, amount)
        //     expect(await usdc.allowance(owner.address, routerV2.target)).to.equal(amount)

        //     let swapID = await swapIDKeeper.calcSwapID(routerV2.target, underlyingToken.target, owner.address, amount.toString(), otherAccount.address, "250")
        //     let calldata = await theiaCallData.genSwapInAutoCallData(underlyingToken.target, amount.toString(), otherAccount.address, swapID, 18, underlyingToken.target)
        //     let uuid = await c3SwapIDKeeper.calcCallerUUID(c3Caller.target, "1", routerV2.target.toLowerCase(), "250", calldata)
        //     // console.log(underlyingToken.target, owner.address, otherAccount.address.toString().toLowerCase(),swapID,uuid)
        //     await expect(routerV2.swapOutAuto(underlyingToken.target, amount.toString(), routerV2.target, otherAccount.address, underlyingToken.target, 18, 250))
        //         .to.emit(routerV2, "LogSwapOut").withArgs(underlyingToken.target, owner.address, otherAccount.address.toString().toLowerCase(), amount.toString(), chainID, 250, 0, swapID, calldata)
        //         .to.emit(c3Caller, "LogC3Call").withArgs("1", uuid, routerV2.target, "250", routerV2.target.toLowerCase(), calldata)

        //     expect(await usdc.balanceOf(underlyingToken.target)).to.equal(amount)

        //     await expect(c3CallerProxy.execute("1", uuid, routerV2.target, chainID.toString(), "sourceTxHash", "", calldata))
        //         .to.emit(c3Caller, "LogExecCall").withArgs("1", routerV2.target, true, uuid, chainID, "sourceTxHash", calldata, "0x0000000000000000000000000000000000000000000000000000000000000001")
        //         .to.emit(routerV2, "LogSwapIn").withArgs(underlyingToken.target, otherAccount.address, swapID, amount.toString(), chainID, chainID, "sourceTxHash")

        //     expect(await underlyingToken.balanceOf(otherAccount.address)).to.equal(0)
        //     expect(await usdc.balanceOf(otherAccount.address)).to.equal(amount)
        // });


        // it("swapOutAuto Underlying fallback", async function () {
        //     let amount = web3.utils.toNumber("1000000000000000000")

        //     let swapID = await swapIDKeeper.calcSwapID(routerV2.target, underlyingToken.target, owner.address, amount.toString(), otherAccount.address, "250")
        //     let calldata = await theiaCallData.genSwapInAutoCallData(underlyingToken.target, amount.toString(), otherAccount.address, swapID, 18, underlyingToken.target)
        //     let uuid = await c3SwapIDKeeper.calcCallerUUID(c3Caller.target, "1", routerV2.target.toLowerCase(), "250", calldata)

        //     await swapIDKeeper.registerSwapout(swapID, 1)
        //     let result = "0x08c379a00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000001754523a696e73756666696369656e742062616c616e6365000000000000000000"
        //     let fallbackdata = await c3Caller.getFallbackCallData("1", calldata, result)

        //     await expect(c3CallerProxy.execute("1", uuid, routerV2.target, chainID.toString(), "sourceTxHash", routerV2.target, calldata))
        //         .to.emit(c3Caller, "LogExecCall").withArgs("1", routerV2.target, false, uuid, chainID, "sourceTxHash", calldata, result)
        //         .to.emit(c3Caller, "LogFallbackCall").withArgs("1", uuid, routerV2.target, fallbackdata)

        //     await usdc.transfer(underlyingToken.target, amount)

        //     await expect(c3CallerProxy.c3Fallback("1", uuid, routerV2.target, chainID.toString(), "failTxHash", fallbackdata, result))
        //         .to.emit(c3Caller, "LogExecFallback").withArgs("1", routerV2.target, true, uuid, chainID, "failTxHash", result, fallbackdata, "0x0000000000000000000000000000000000000000000000000000000000000001")
        //         .to.emit(routerV2, "LogSwapFallback").withArgs(swapID, underlyingToken.target, otherAccount.address, amount.toString(), calldata.substring(0, 10), "0x" + calldata.substring(10), result)

        //     expect(await usdc.balanceOf(otherAccount.address)).to.equals(amount)
        // });

        // it("swapOutAuto Native fallback", async function () {
        //     let amount = web3.utils.toNumber("1000000000000000000")
        //     let to = "0x3333333333333333333333333333333333333333"

        //     let result = "0x08c379a00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000001754523a696e73756666696369656e742062616c616e6365000000000000000000"

        //     let swapID = await swapIDKeeper.calcSwapID(routerV2.target, erc20Token.target, otherAccount.address, amount.toString(), to, "250")
        //     let c3callerdata = await theiaCallData.genSwapInAutoCallData(erc20Token.target, amount.toString(), to, swapID, 18, erc20Token.target)
        //     let uuid = await c3SwapIDKeeper.calcCallerUUID(c3Caller.target, "1", routerV2.target.toLowerCase(), "250", c3callerdata)
        //     let fallbackdata = await c3Caller.getFallbackCallData("1", c3callerdata, result)

        //     // await expect(routerV2.swapInAuto(swapID, erc20Token.target, to, amount)).to.emit(routerV2, "LogSwapIn").withArgs(erc20Token.target, to, swapID, amount, 0, chainID, "")

        //     await expect(c3CallerProxy.execute("1", uuid, routerV2.target, chainID.toString(), "sourceTxHash", routerV2.target, c3callerdata))
        //         .to.emit(c3Caller, "LogExecCall").withArgs("1", routerV2.target, false, uuid, chainID, "sourceTxHash", c3callerdata, result)
        //         .to.emit(c3Caller, "LogFallbackCall").withArgs("1", uuid, routerV2.target, fallbackdata)

        //     await otherAccount.sendTransaction({
        //         to: weth.target,
        //         value: amount,
        //     });
        //     await weth.connect(otherAccount).transfer(erc20Token.target, amount)

        //     await swapIDKeeper.registerSwapout(swapID, 1)

        //     await expect(c3CallerProxy.c3Fallback("1", uuid, routerV2.target, chainID.toString(), "failTxHash", fallbackdata, result))
        //         .to.emit(c3Caller, "LogExecFallback").withArgs("1", routerV2.target, true, uuid, chainID, "failTxHash", result, fallbackdata, "0x0000000000000000000000000000000000000000000000000000000000000001")
        //         .to.emit(routerV2, "LogSwapFallback").withArgs(swapID, erc20Token.target, to, amount.toString(), c3callerdata.substring(0, 10), "0x" + c3callerdata.substring(10), result)

        //     expect(await ethers.provider.getBalance(to)).to.equals(amount)
        // });


        // it("callAndSwapOut", async function () {
        //     let amount = web3.utils.toNumber("10000000000000000000")
        //     let to = otherAccount.address

        //     let DemoRouter = await ethers.getContractFactory("DemoRouter");
        //     let demoRouter = await DemoRouter.deploy(weth.target, owner.address, swapIDKeeper.target, c3CallerProxy.target, 2);

        //     let dexData = demoXCallData(amount)

        //     await usdc.approve(routerV2.target, amount)

        //     await owner.sendTransaction({
        //         to: weth.target,
        //         value: amount,
        //     });
        //     await weth.transfer(demoRouter.target, amount)

        //     expect(await weth.balanceOf(demoRouter.target)).to.equals(amount)

        //     let swapID = await swapIDKeeper.calcSwapID(routerV2.target, underlyingToken.target, owner.address, amount.toString(), otherAccount.address, "250")
        //     let calldata = await theiaCallData.genSwapInAutoCallData(erc20Token.target, amount.toString(), otherAccount.address, swapID, 18, erc20Token.target)
        //     let uuid = await c3SwapIDKeeper.calcCallerUUID(c3Caller.target, "1", routerV2.target.toLowerCase(), "250", calldata)

        //     await expect(routerV2.callAndSwapOut(underlyingToken.target, amount.toString(), routerV2.target, erc20Token.target, to, erc20Token.target, 18, 250, demoRouter.target, dexData))
        //         .to.emit(routerV2, "LogSwapOut").withArgs(erc20Token.target, owner.address, to.toString().toLowerCase(), amount.toString(), chainID, 250, 0, swapID, calldata)
        //         .to.emit(c3Caller, "LogC3Call").withArgs("1", uuid, routerV2.target, "250", routerV2.target.toLowerCase(), calldata)
        // });

        // it("callAndSwapOut fallback", async function () {
        //     let amount = web3.utils.toNumber("10000000000000000000")
        //     // let to = otherAccount.address
        //     let to = "0x1234567890123456789012345678901234567890"

        //     let DemoRouter = await ethers.getContractFactory("DemoRouter");
        //     let demoRouter = await DemoRouter.deploy(weth.target, owner.address, swapIDKeeper.target, c3CallerProxy.target, 2);

        //     let dexData = demoXCallData(amount)

        //     await usdc.approve(routerV2.target, amount)

        //     await owner.sendTransaction({
        //         to: weth.target,
        //         value: amount,
        //     });
        //     await weth.transfer(demoRouter.target, amount)

        //     expect(await weth.balanceOf(demoRouter.target)).to.equals(amount)

        //     let swapID = await swapIDKeeper.calcSwapID(routerV2.target, underlyingToken.target, owner.address, amount.toString(), to, "250")
        //     let calldata = await theiaCallData.genSwapInAutoCallData(erc20Token.target, amount.toString(), to, swapID, 18, erc20Token.target)
        //     let uuid = await c3SwapIDKeeper.calcCallerUUID(c3Caller.target, "1", routerV2.target.toLowerCase(), "250", calldata)

        //     await expect(routerV2.callAndSwapOut(underlyingToken.target, amount.toString(), routerV2.target, erc20Token.target, to, erc20Token.target, 18, 250, demoRouter.target, dexData))
        //         .to.emit(routerV2, "LogSwapOut").withArgs(erc20Token.target, owner.address, to.toString().toLowerCase(), amount.toString(), chainID, 250, 0, swapID, calldata)
        //         .to.emit(c3Caller, "LogC3Call").withArgs("1", uuid, routerV2.target, "250", routerV2.target.toLowerCase(), calldata)

        //     expect(await weth.balanceOf(demoRouter.target)).to.equals(0)
        //     expect(await weth.balanceOf(erc20Token.target)).to.equals(amount)

        //     let calldata2 = await theiaCallData.genSwapInAutoCallData(erc20Token.target, amount.toString(), to, swapID, 6, erc20Token.target)
        //     await expect(c3CallerProxy.execute("1", uuid, routerV2.target, chainID.toString(), "sourceTxHash", routerV2.target, calldata2))
        //         .to.emit(c3Caller, "LogExecCall").withArgs("1", routerV2.target, false, uuid, chainID, "sourceTxHash", calldata2, "0x08c379a00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000001954523a746f6b656e446563696d616c73206469736d6174636800000000000000")
        //         .to.emit(c3Caller, "LogFallbackCall")

        //     let fallbackdata = await c3Caller.getFallbackCallData("1", calldata, "0x0000000000000000000000")
        //     await expect(c3CallerProxy.c3Fallback("1", uuid, routerV2.target, chainID.toString(), "failTxHash", fallbackdata, "0x0000000000000000000000"))
        //         .to.emit(c3Caller, "LogExecFallback").withArgs("1", routerV2.target, true, uuid, chainID, "failTxHash", "0x0000000000000000000000", fallbackdata, "0x0000000000000000000000000000000000000000000000000000000000000001")
        //         .to.emit(routerV2, "LogSwapFallback").withArgs(swapID, erc20Token.target, to, amount.toString(), calldata.substring(0, 10), "0x" + calldata.substring(10), "0x0000000000000000000000")

        //     expect(await weth.balanceOf(erc20Token.target)).to.equals(0)
        //     expect(await weth.balanceOf(owner.address)).to.equals(0)
        //     expect(await weth.balanceOf(to)).to.equals(0)
        //     expect(await ethers.provider.getBalance(to)).to.equals(amount)
        //     expect(await erc20Token.balanceOf(to)).to.equals(0)

        // });

        // it("swapOutAndCall", async function () {
        //     let amount = web3.utils.toNumber("10000000000000000000")
        //     let to = otherAccount.address

        //     let DemoRouter = await ethers.getContractFactory("DemoRouter");
        //     let demoRouter = await DemoRouter.deploy(weth.target, owner.address, swapIDKeeper.target, c3CallerProxy.target, 2);

        //     let dexData = demoXCallData(amount)

        //     await usdc.approve(routerV2.target, amount)

        //     await owner.sendTransaction({
        //         to: weth.target,
        //         value: amount,
        //     });
        //     await weth.transfer(demoRouter.target, amount)

        //     expect(await weth.balanceOf(demoRouter.target)).to.equals(amount)

        //     let swapID = await swapIDKeeper.calcSwapID(routerV2.target, underlyingToken.target, owner.address, amount.toString(), to, "250")
        //     let calldata = await theiaCallData.genCallData4SwapInAndCall(underlyingToken.target, amount.toString(), to, false, demoRouter.target, swapID, 18, underlyingToken.target, dexData)
        //     let uuid = await c3SwapIDKeeper.calcCallerUUID(c3Caller.target, "1", routerV2.target.toLowerCase(), "250", calldata)

        //     await expect(routerV2.swapOutAndCall(underlyingToken.target, amount.toString(), routerV2.target, to, underlyingToken.target, 18, 250, false, demoRouter.target, dexData))
        //         .to.emit(routerV2, "LogSwapOut").withArgs(underlyingToken.target, owner.address, to.toString().toLowerCase(), amount.toString(), chainID, 250, 0, swapID, calldata)
        //         .to.emit(c3Caller, "LogC3Call").withArgs("1", uuid, routerV2.target, "250", routerV2.target.toLowerCase(), calldata)

        //     expect(await usdc.balanceOf(underlyingToken.target)).to.equals(amount)

        //     await expect(c3CallerProxy.execute("1", uuid, routerV2.target, chainID.toString(), "sourceTxHash", routerV2.target, calldata))
        //         .to.emit(c3Caller, "LogExecCall").withArgs("1", routerV2.target, true, uuid, chainID, "sourceTxHash", calldata, "0x0000000000000000000000000000000000000000000000000000000000000001")
        //         .to.emit(routerV2, "LogSwapIn").withArgs(underlyingToken.target, to, swapID, amount, chainID, chainID, "sourceTxHash")

        //     expect(await usdc.balanceOf(underlyingToken.target)).to.equals(0)
        //     // expect(await usdc.balanceOf(routerV2.target)).to.equals(0)
        //     // expect(await usdc.balanceOf(to)).to.equals(amount)

        // });

        // it("DepositNative", async function () {
        //     let amount = web3.utils.toNumber("10000000000000000000")
        //     let to = "0x1111111111111111111111111111111111111111"
        //     let ABI = [{
        //         "inputs": [
        //             {
        //                 "internalType": "address",
        //                 "name": "token",
        //                 "type": "address"
        //             },
        //             {
        //                 "internalType": "address",
        //                 "name": "to",
        //                 "type": "address"
        //             }
        //         ],
        //         "name": "depositNative",
        //         "outputs": [
        //             {
        //                 "internalType": "uint256",
        //                 "name": "",
        //                 "type": "uint256"
        //             }
        //         ],
        //         "stateMutability": "payable",
        //         "type": "function"
        //     }]
        //     let contract = new web3.eth.Contract(ABI);
        //     let calldata = contract.methods.depositNative(erc20Token.target, to).encodeABI()
        //     await expect(otherAccount.sendTransaction({
        //         to: routerV2.target,
        //         value: amount,
        //         data: calldata
        //     })).to.emit(erc20Token, "Transfer").withArgs("0x0000000000000000000000000000000000000000", to, amount.toString());

        //     expect(await erc20Token.balanceOf(to)).to.equal(amount)
        // });

        // it("DepositNative", async function () {
        //     let amount = web3.utils.toNumber("10000000000000000000")
        //     let to = "0x1111111111111111111111111111111111111111"
        //     let ABI = [{
        //         "inputs": [
        //             {
        //                 "internalType": "address",
        //                 "name": "token",
        //                 "type": "address"
        //             },
        //             {
        //                 "internalType": "address",
        //                 "name": "to",
        //                 "type": "address"
        //             }
        //         ],
        //         "name": "depositNative",
        //         "outputs": [
        //             {
        //                 "internalType": "uint256",
        //                 "name": "",
        //                 "type": "uint256"
        //             }
        //         ],
        //         "stateMutability": "payable",
        //         "type": "function"
        //     }]
        //     let contract = new web3.eth.Contract(ABI);
        //     let calldata = contract.methods.depositNative(erc20Token.target, to).encodeABI()
        //     await expect(otherAccount.sendTransaction({
        //         to: routerV2.target,
        //         value: amount,
        //         data: calldata
        //     })).to.emit(erc20Token, "Transfer").withArgs("0x0000000000000000000000000000000000000000", to, amount.toString());

        //     expect(await erc20Token.balanceOf(to)).to.equal(amount)
        // });

        // it("WithdrawNative", async function () {
        //     let amount = web3.utils.toNumber("10000000000000000000")
        //     let ABI = [{
        //         "inputs": [
        //             {
        //                 "internalType": "address",
        //                 "name": "token",
        //                 "type": "address"
        //             },
        //             {
        //                 "internalType": "address",
        //                 "name": "to",
        //                 "type": "address"
        //             }
        //         ],
        //         "name": "depositNative",
        //         "outputs": [
        //             {
        //                 "internalType": "uint256",
        //                 "name": "",
        //                 "type": "uint256"
        //             }
        //         ],
        //         "stateMutability": "payable",
        //         "type": "function"
        //     }]
        //     let contract = new web3.eth.Contract(ABI);
        //     let calldata = contract.methods.depositNative(erc20Token.target, owner.address).encodeABI()
        //     await owner.sendTransaction({
        //         to: routerV2.target,
        //         value: amount,
        //         data: calldata
        //     })
        //     expect(await erc20Token.balanceOf(owner.address)).to.equal(amount)

        //     await expect(routerV2.connect(owner).withdrawNative(erc20Token.target, amount.toString(), routerV2.target)).to.emit(erc20Token, "Transfer")
        //         .withArgs(owner.address, "0x0000000000000000000000000000000000000000", amount.toString());

        //     expect(await erc20Token.balanceOf(owner.address)).to.equal(0)
        //     expect(await ethers.provider.getBalance(routerV2.target)).to.equal(amount)
        // });

    // });

});
