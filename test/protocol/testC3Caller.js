const { expect } = require("chai");
const { Web3, eth } = require('web3');
let web3 = new Web3(Web3.givenProvider);
const BN = require('bn.js');

describe("protocal", function () {
    let owner
    let otherAccount
    let c3Caller
    let c3SwapIDKeeper
    let c3CallerProxy


    async function deployC3Caller() {
        // Contracts are deployed using the first signer/account by default
        const [_owner, _otherAccount] = await ethers.getSigners();

        const C3SwapIDKeeper = await ethers.getContractFactory("contracts/protocol/C3SwapIDKeeper.sol:C3SwapIDKeeper");
        c3SwapIDKeeper = await C3SwapIDKeeper.deploy(_owner.address);

        const C3Caller = await ethers.getContractFactory("contracts/protocol/C3Caller.sol:C3Caller");
        c3Caller = await C3Caller.deploy(_owner.address, c3SwapIDKeeper.target);

        const C3CallerProxy = await ethers.getContractFactory("C3CallerProxy");
        c3CallerProxy = await C3CallerProxy.deploy(_owner.address, c3Caller.target);

        await c3SwapIDKeeper.addSupportedCaller(c3Caller.target)

        await c3Caller.addOperator(c3CallerProxy.target)

        owner = _owner
        otherAccount = _otherAccount
    }


    beforeEach(async () => {
        await deployC3Caller()
    })

    describe("protocal.C3Caller", function () {
        it("constructor", async function () {
            expect(await c3Caller.mpc()).to.equal(owner.address)
            expect(await c3Caller.isOperator(owner.address)).to.equal(true)
        });

        it("c3call", async function () {
            let data = web3.utils.randomBytes(10)
            let uuid = await c3SwapIDKeeper.calcCallerUUID(c3Caller.target, "1", "to", "_toChainID", data)
            await expect(c3Caller.connect(otherAccount).c3call("1", "to", "_toChainID", data))
                .to.emit(c3Caller, "LogC3Call").withArgs("1", uuid, otherAccount.address, "_toChainID", "to", data)
        });

        it("execute with error to address", async function () {
            let data = "0x00000000"
            let uuid = await c3SwapIDKeeper.calcCallerUUID(c3Caller.target, "1", "to", "_toChainID", data)
            // await expect(c3Caller.execute("1", uuid, otherAccount.address, "_fromChainID", "_sourceTx", "_fallback", data)).to.revertedWithoutReason();

            let c3Fallback = "0x2b716a080000000000000000000000000000000000000000000000000000000000000001" + uuid.toString().substring(2) + "000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
            await expect(c3Caller.execute("1", uuid, c3SwapIDKeeper.target, "_fromChainID", "_sourceTx", "_fallback", data))
                .to.emit(c3Caller, "LogExecCall").withArgs("1", c3SwapIDKeeper.target, false, uuid, "_fromChainID", "_sourceTx", data)
                .emit(c3Caller, "LogFallbackCall").withArgs("1", uuid, "_fallback", c3Fallback, "0x")

        });

        it("execute DemoRouter", async function () {
            let DemoSwapIDKeeper = await ethers.getContractFactory("DemoSwapIDKeeper");
            let demoSwapIDKeeper = await DemoSwapIDKeeper.deploy(owner.address);

            const WETH = await ethers.getContractFactory("WETH");
            let weth = await WETH.deploy();

            const C3ERC20 = await ethers.getContractFactory("C3ERC20");
            let erc20Token = await C3ERC20.deploy("ctmETHOD", "ctmETH", 18, weth.target, owner.address);

            let DemoRouter = await ethers.getContractFactory("DemoRouter");
            let demoRouter = await DemoRouter.deploy(weth.target, owner.address, demoSwapIDKeeper.target, c3CallerProxy.target);

            await demoSwapIDKeeper.addSupportedCaller(demoRouter.target)

            let amount = new BN("10000000000000000000000")
            let data = "0xd9d9b745dab0d7fd87aa592f8a2a3e6ba011a8719667618183607cf204bcea20fd31f75d000000000000000000000000e6e340d132b5f46d1e472debcd681b2abc16e57e000000000000000000000000307866333946643665353161616438384636463400000000000000000000000000000000000000000000021e19e0c9bab24000000000000000000000000000000000000000000000000000000000000000007a69"
            let uuid = await c3SwapIDKeeper.calcCallerUUID(c3Caller.target, "1", demoRouter.target, "toChain", data)
            // console.log(uuid)

            await expect(demoRouter.connect(otherAccount).swapOut(erc20Token.target, amount.toString(), demoRouter.target, owner.address.toString(), "toChain")).to
                // .emit(demoRouter, "LogSwapOut").withArgs(erc20Token.target, otherAccount.address, demoRouter.target, amount.toString(), 31337, "toChain", "0", "0xdab0d7fd87aa592f8a2a3e6ba011a8719667618183607cf204bcea20fd31f75d", "", "0x")
                .emit(c3Caller, "LogC3Call").withArgs("1", "0xd1214ee27fed9820cfdef5f0e58cdb14c7f36ad7eab7b8c122799c4e2b40cb75", c3CallerProxy.target, "toChain", demoRouter.target, data)

            await expect(c3CallerProxy.execute("1", uuid, demoRouter.target, "_fromChainID", "_sourceTx", "", data))
                .to.emit(c3Caller, "LogExecCall").withArgs("1", demoRouter.target, true, uuid, "_fromChainID", "_sourceTx", data)
        });

    });

});


