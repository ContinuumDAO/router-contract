const { expect } = require("chai");
const { Web3 } = require('web3');
let web3 = new Web3(Web3.givenProvider);
const BN = require('bn.js');

describe("TheiaRouter", function () {
    let routerV2
    let erc20Token
    let weth
    let owner
    let otherAccount
    let chainID
    let swapIDKeeper
    let c3SwapIDKeeper, c3CallerProxy, c3Caller


    async function deployRouterV2() {
        // Contracts are deployed using the first signer/account by default
        const [_owner, _otherAccount] = await ethers.getSigners();
        const WETH = await ethers.getContractFactory("WETH");
        weth = await WETH.deploy();

        const TheiaSwapIDKeeper = await ethers.getContractFactory("TheiaSwapIDKeeper");
        swapIDKeeper = await TheiaSwapIDKeeper.deploy(_owner);

        const TheiaRouter = await ethers.getContractFactory("TheiaRouter");
        routerV2 = await TheiaRouter.deploy(weth, _owner, swapIDKeeper.target, c3CallerProxy.target, 1);

        await swapIDKeeper.addSupportedCaller(routerV2.target)
        await routerV2.addOperator(c3Caller.target)

        owner = _owner
        otherAccount = _otherAccount
        chainID = await routerV2.cID();
    }


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
    }

    async function deployC3ERC20(name, symbol, decimals, underlying, vault) {
        // Contracts are deployed using the first signer/account by default
        const [_owner, _otherAccount] = await ethers.getSigners();
        const TheiaERC20 = await ethers.getContractFactory("TheiaERC20");
        erc20Token = await TheiaERC20.deploy(name, symbol, decimals, underlying, vault);
    }


    beforeEach(async () => {
        await deployC3Caller()
        await deployRouterV2()
        await deployC3ERC20("ctmETHOD", "ctmETH", 18, weth.target, routerV2.target)
    })


    describe("TheiaERC20", function () {
        it("Deploy", async function () {
            expect(await erc20Token.owner()).to.equal(routerV2.target)

            expect(await routerV2.mpc()).to.equal(owner.address)
        });
        it("FeeConfig", async function () {
            let testcases = [{
                rules: {
                    from: chainID,
                    to: 250,
                    min: web3.utils.toNumber("100000000000000"), // 0.0001 eth
                    max: web3.utils.toNumber("100000000000000000"), // 0.1 eth
                    rate: 500,
                    payfrom: 1
                },
                case: [{
                    from: 0,
                    to: 250,
                    amount: web3.utils.toNumber("10000000000000000000"), // 10
                    fee: web3.utils.toNumber("5000000000000000")
                }, {
                    from: 0,
                    to: 250,
                    amount: web3.utils.toNumber("190000000000000000"), // 0.19
                    fee: web3.utils.toNumber("100000000000000") // 0.0001 eth
                }, {
                    from: 0,
                    to: 250,
                    amount: web3.utils.toNumber("210000000000000000000"), // 210
                    fee: web3.utils.toNumber("100000000000000000") // 0.1 eth
                }, {
                    from: chainID,
                    to: 0,
                    amount: web3.utils.toNumber("10000000000000000000"), // 10
                    fee: web3.utils.toNumber("0") // 0 eth
                }]
            }, {
                rules: {
                    from: chainID,
                    to: 250,
                    min: web3.utils.toNumber("100000000000000"), // 0.0001 eth
                    max: web3.utils.toNumber("100000000000000000"), // 0.1 eth
                    rate: 500,
                    payfrom: 2
                },
                case: [{
                    from: chainID,
                    to: 0,
                    amount: web3.utils.toNumber("10000000000000000000"), // 10
                    fee: web3.utils.toNumber("5000000000000000")
                }, {
                    from: chainID,
                    to: 0,
                    amount: web3.utils.toNumber("190000000000000000"), // 0.19
                    fee: web3.utils.toNumber("100000000000000") // 0.0001 eth
                }, {
                    from: chainID,
                    to: 0,
                    amount: web3.utils.toNumber("210000000000000000000"), // 210
                    fee: web3.utils.toNumber("100000000000000000") // 0.1 eth
                }]
            }]

            for (let index = 0; index < testcases.length; index++) {
                const element = testcases[index];
                await routerV2.connect(owner).setTokenFeeConfig(erc20Token.target, element.rules.from, element.rules.to,
                    element.rules.max.toString(), element.rules.min.toString(), element.rules.rate, element.rules.payfrom)

                for (let j = 0; j < element.case.length; j++) {
                    let c = element.case[j];
                    let re = await routerV2.calcSwapFee(c.from, c.to, erc20Token.target, c.amount.toString())
                    expect(re.toString()).to.equal(c.fee.toString())
                }
            }
        });

    });

    describe("TheiaRouter", function () {
        it("SwapOut", async function () {
            expect(await erc20Token.isMinter(routerV2.target)).to.equal(true)
            let amount = web3.utils.toNumber("1000000000000000000")
            await otherAccount.sendTransaction({
                to: weth.target,
                value: amount,
            });

            expect(await weth.balanceOf(otherAccount.address)).to.equal(amount)

            await erc20Token.connect(otherAccount).deposit()
            expect(await erc20Token.balanceOf(otherAccount.address)).to.equal(amount)

            let swapID = await swapIDKeeper.calcSwapID(routerV2.target, erc20Token.target, otherAccount.address, amount.toString(), otherAccount.address, "250")
            let calldata = await routerV2.genSwapInAutoCallData(erc20Token.target, amount.toString(), otherAccount.address, swapID)

            // routerV2.target solidity string is different from calldata string
            // let encodedata = await c3SwapIDKeeper.calcCallerEncode(c3Caller.target, "1", routerV2.target.toLowerCase(), "250", calldata)
            let uuid = await c3SwapIDKeeper.calcCallerUUID(c3Caller.target, "1", routerV2.target.toLowerCase(), "250", calldata)
            // console.log(uuid, web3.utils.toHex(250), routerV2.target)

            await expect(routerV2.connect(otherAccount)["swapOut(address,uint256,address,address,uint256)"](erc20Token.target, amount.toString(), routerV2.target, otherAccount.address, 250))
                .to.emit(routerV2, "LogSwapOut").withArgs(erc20Token.target, otherAccount.address, otherAccount.address.toString().toLowerCase(), amount.toString(), chainID, 250, 0, swapID, calldata)
                .to.emit(c3Caller, "LogC3Call").withArgs("1", uuid, routerV2.target, "250", routerV2.target.toLowerCase(), calldata)


            await expect(c3CallerProxy.execute("1", uuid, routerV2.target, chainID.toString(), "sourceTxHash", "", calldata))
                .to.emit(c3Caller, "LogExecCall").withArgs("1", routerV2.target, true, uuid, chainID, "sourceTxHash", calldata, "0x0000000000000000000000000000000000000000000000000000000000000001")
                .to.emit(routerV2, "LogSwapIn").withArgs(erc20Token.target, otherAccount.address, swapID, amount.toString(), chainID, chainID, "sourceTxHash")

            expect(await erc20Token.balanceOf(otherAccount.address)).to.equal(0)
            // await expect(routerV2.swapInAuto(swapID, erc20Token.target, otherAccount.address, amount.toString()))
            //     .to.be.rejectedWith("FeeConfig: Invalid chainID");
        });

        it("Fallback", async function () {
            expect(await erc20Token.isMinter(routerV2.target)).to.equal(true)
            let amount = web3.utils.toNumber("1000000000000000000")
            await otherAccount.sendTransaction({
                to: weth.target,
                value: amount,
            });
            await erc20Token.connect(otherAccount).deposit()

            let swapID = await swapIDKeeper.calcSwapID(routerV2.target, erc20Token.target, otherAccount.address, amount.toString(), otherAccount.address, "250")
            let calldata = await routerV2.genSwapInAutoCallData(erc20Token.target, amount.toString(), otherAccount.address, swapID)

            await expect(routerV2.connect(otherAccount)["swapOut(address,uint256,address,address,uint256)"](erc20Token.target, amount.toString(), routerV2.target, otherAccount.address, 250))
                .to.emit(routerV2, "LogSwapOut").withArgs(erc20Token.target, otherAccount.address, otherAccount.address.toString().toLowerCase(), amount.toString(), chainID, 250, 0, swapID, calldata)

            let uuid = await c3SwapIDKeeper.calcCallerUUID(c3Caller.target, "1", erc20Token.target.toLowerCase(), "250", calldata)
            let fallbackdata = "0xb121f51d000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000120000000000000000000000000000000000000000000000000000000000000008401b0e5e00224329e01f2fae9573c96b436220758e129c2537e3bbdcf22a9ef2d9fa13dc2000000000000000000000000286b8decd5ed79c962b2d8f4346cd97ff0e2c35200000000000000000000000070997970c51812dc3a010c7d01b50e0d17dc79c80000000000000000000000000000000000000000000000000de0b6b3a7640000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
            await expect(c3CallerProxy.execute("1", uuid, erc20Token.target, chainID.toString(), "sourceTxHash", routerV2.target, calldata))
                .to.emit(c3Caller, "LogExecCall").withArgs("1", erc20Token.target, false, uuid, chainID, "sourceTxHash", calldata, "0x")
                .emit(c3Caller, "LogFallbackCall").withArgs("1", uuid, routerV2.target, fallbackdata)

            await expect(c3CallerProxy.c3Fallback("1", uuid, routerV2.target, chainID.toString(), "failTxHash", fallbackdata, "0x"))
                .to.emit(c3Caller, "LogExecFallback").withArgs("1", routerV2.target, true, uuid, chainID, "failTxHash", "0x", fallbackdata, "0x0000000000000000000000000000000000000000000000000000000000000001")
                .emit(routerV2, "LogSwapFallback").withArgs(swapID, erc20Token.target, otherAccount.address, amount.toString(), "0x01b0e5e0", "0x" + calldata.substring(10), "0x")

        });

        it("DepositNative", async function () {
            let amount = web3.utils.toNumber("10000000000000000000")
            let to = "0x1111111111111111111111111111111111111111"
            let ABI = [{
                "inputs": [
                    {
                        "internalType": "address",
                        "name": "token",
                        "type": "address"
                    },
                    {
                        "internalType": "address",
                        "name": "to",
                        "type": "address"
                    }
                ],
                "name": "depositNative",
                "outputs": [
                    {
                        "internalType": "uint256",
                        "name": "",
                        "type": "uint256"
                    }
                ],
                "stateMutability": "payable",
                "type": "function"
            }]
            let contract = new web3.eth.Contract(ABI);
            let calldata = contract.methods.depositNative(erc20Token.target, to).encodeABI()
            await expect(otherAccount.sendTransaction({
                to: routerV2.target,
                value: amount,
                data: calldata
            })).to.emit(erc20Token, "Transfer").withArgs("0x0000000000000000000000000000000000000000", to, amount.toString());

            expect(await erc20Token.balanceOf(to)).to.equal(amount)
        });

        it("DepositNative", async function () {
            let amount = web3.utils.toNumber("10000000000000000000")
            let to = "0x1111111111111111111111111111111111111111"
            let ABI = [{
                "inputs": [
                    {
                        "internalType": "address",
                        "name": "token",
                        "type": "address"
                    },
                    {
                        "internalType": "address",
                        "name": "to",
                        "type": "address"
                    }
                ],
                "name": "depositNative",
                "outputs": [
                    {
                        "internalType": "uint256",
                        "name": "",
                        "type": "uint256"
                    }
                ],
                "stateMutability": "payable",
                "type": "function"
            }]
            let contract = new web3.eth.Contract(ABI);
            let calldata = contract.methods.depositNative(erc20Token.target, to).encodeABI()
            await expect(otherAccount.sendTransaction({
                to: routerV2.target,
                value: amount,
                data: calldata
            })).to.emit(erc20Token, "Transfer").withArgs("0x0000000000000000000000000000000000000000", to, amount.toString());

            expect(await erc20Token.balanceOf(to)).to.equal(amount)
        });

        it("WithdrawNative", async function () {
            let amount = web3.utils.toNumber("10000000000000000000")
            let ABI = [{
                "inputs": [
                    {
                        "internalType": "address",
                        "name": "token",
                        "type": "address"
                    },
                    {
                        "internalType": "address",
                        "name": "to",
                        "type": "address"
                    }
                ],
                "name": "depositNative",
                "outputs": [
                    {
                        "internalType": "uint256",
                        "name": "",
                        "type": "uint256"
                    }
                ],
                "stateMutability": "payable",
                "type": "function"
            }]
            let contract = new web3.eth.Contract(ABI);
            let calldata = contract.methods.depositNative(erc20Token.target, owner.address).encodeABI()
            await owner.sendTransaction({
                to: routerV2.target,
                value: amount,
                data: calldata
            })
            expect(await erc20Token.balanceOf(owner.address)).to.equal(amount)

            await expect(routerV2.connect(owner).withdrawNative(erc20Token.target, amount.toString(), routerV2.target)).to.emit(erc20Token, "Transfer")
                .withArgs(owner.address, "0x0000000000000000000000000000000000000000", amount.toString());

            expect(await erc20Token.balanceOf(owner.address)).to.equal(0)
            expect(await ethers.provider.getBalance(routerV2.target)).to.equal(amount)
        });

    });

});
