const { expect } = require("chai");
const { Web3 } = require('web3');
let web3 = new Web3(Web3.givenProvider);
const BN = require('bn.js');

describe("CtmDaoV1", function () {
    let routerV1
    let erc20Token
    let weth
    let owner
    let otherAccount
    let chainID
    let ctmSwapIDKeeper


    async function deployRouterV1() {
        // Contracts are deployed using the first signer/account by default
        const [_owner, _otherAccount] = await ethers.getSigners();
        const WETH = await ethers.getContractFactory("WETH");
        weth = await WETH.deploy();

        const CtmSwapIDKeeper = await ethers.getContractFactory("CtmSwapIDKeeper");
        ctmSwapIDKeeper = await CtmSwapIDKeeper.deploy(_owner);

        const CtmDaoV1Router = await ethers.getContractFactory("CtmDaoV1Router");
        routerV1 = await CtmDaoV1Router.deploy(weth, _owner, ctmSwapIDKeeper.target);

        await ctmSwapIDKeeper.addSupportedCaller(routerV1.target)

        owner = _owner
        otherAccount = _otherAccount
        chainID = await routerV1.cID();
    }

    async function deployCtmDaoV1ERC20(name, symbol, decimals, underlying, vault) {
        // Contracts are deployed using the first signer/account by default
        const [_owner, _otherAccount] = await ethers.getSigners();
        const CtmDaoV1ERC20 = await ethers.getContractFactory("CtmDaoV1ERC20");
        erc20Token = await CtmDaoV1ERC20.deploy(name, symbol, decimals, underlying, vault);
    }


    beforeEach(async () => {
        await deployRouterV1()
        await deployCtmDaoV1ERC20("ctmETHOD", "ctmETH", 18, weth.target, routerV1.target)
    })


    describe("CtmDaoV1ERC20", function () {
        it("Deploy", async function () {
            expect(await erc20Token.owner()).to.equal(routerV1.target)

            expect(await routerV1.mpc()).to.equal(owner.address)

            const DeployRouterV1 = await ethers.getContractFactory("DeployRouterV1");
            let aDeployRouterV1 = await DeployRouterV1.connect(owner).deploy();

            await expect(aDeployRouterV1.connect(owner).newRouter(weth.target, owner.address, ctmSwapIDKeeper.target, "router1")).to.emit(aDeployRouterV1, "NewRouter")
            // .withArgs("0x73f6cDee996871978D9f54753bC1586C777Fbe34")

            const DeployTokenFactoryV1 = await ethers.getContractFactory("DeployTokenFactoryV1");
            let aDeployTokenFactoryV1 = await DeployTokenFactoryV1.deploy();

            await expect(aDeployTokenFactoryV1.connect(owner).newToken("ctmETHOD", "ctmETH", 18, weth.target, routerV1.target)).to.emit(aDeployTokenFactoryV1, "NewToken")
            // .withArgs("0xdF9ACEb66b8dC2B68cf130e203DF70272af2E204")

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
                await routerV1.connect(owner).setTokenFeeConfig(erc20Token.target, element.rules.from, element.rules.to,
                    element.rules.max.toString(), element.rules.min.toString(), element.rules.rate, element.rules.payfrom)

                for (let j = 0; j < element.case.length; j++) {
                    let c = element.case[j];
                    let re = await routerV1.calcSwapFee(c.from, c.to, erc20Token.target, c.amount.toString())
                    expect(re.toString()).to.equal(c.fee.toString())
                }
            }
        });

    });

    describe("CtmDaoV1Router", function () {
        it("AnySwapOut", async function () {
            expect(await erc20Token.isMinter(routerV1.target)).to.equal(true)
            let amount = web3.utils.toNumber("1000000000000000000")
            await otherAccount.sendTransaction({
                to: weth.target,
                value: amount,
            });

            expect(await weth.balanceOf(otherAccount.address)).to.equal(amount)

            await erc20Token.connect(otherAccount).deposit()
            expect(await erc20Token.balanceOf(otherAccount.address)).to.equal(amount)

            let swapID = await ctmSwapIDKeeper.calcSwapID(erc20Token.target, otherAccount.address, otherAccount.address, amount.toString(), "250", routerV1.target)

            await expect(routerV1.connect(otherAccount)["anySwapOut(address,address,uint256,uint256)"](erc20Token.target, otherAccount.address, amount.toString(), 250)).to.emit(routerV1, "LogAnySwapOut")
                .withArgs(erc20Token.target, otherAccount.address, otherAccount.address, amount.toString(), chainID, 250, 0, swapID)

        });
        it("AnySwapOutNonEvm", async function () {
            expect(await erc20Token.isMinter(routerV1.target)).to.equal(true)
            let amount = web3.utils.toNumber("1000000000000000000")
            await otherAccount.sendTransaction({
                to: weth.target,
                value: amount,
            });

            expect(await weth.balanceOf(otherAccount.address)).to.equal(amount)

            await erc20Token.connect(otherAccount).deposit()
            expect(await erc20Token.balanceOf(otherAccount.address)).to.equal(amount)

            let swapID = await ctmSwapIDKeeper.calcNonEvmSwapID(erc20Token.target, otherAccount.address, "otherAccount.address", amount.toString(), 250, routerV1.target)

            await expect(routerV1.connect(otherAccount)["anySwapOut(address,string,uint256,uint256)"](erc20Token.target, "otherAccount.address", amount.toString(), 250)).to.emit(routerV1, "LogAnySwapOutNonEvm")
                .withArgs(erc20Token.target, otherAccount.address, "otherAccount.address", amount.toString(), chainID, 250, 0, swapID)
        });

        it("AnySwapOut WithFee", async function () {
            let rules = {
                from: chainID,
                to: 250,
                min: web3.utils.toNumber("100000000000000"), // 0.0001 eth
                max: web3.utils.toNumber("100000000000000000"), // 0.1 eth
                rate: web3.utils.toNumber("500"),
                payfrom: 1
            }

            await routerV1.connect(owner).setTokenFeeConfig(erc20Token.target, rules.from, rules.to,
                rules.max.toString(), rules.min.toString(), rules.rate.toString(), rules.payfrom)

            expect(await erc20Token.isMinter(routerV1.target)).to.equal(true)
            let amount = web3.utils.toNumber("1000000000000000000")
            await otherAccount.sendTransaction({
                to: weth.target,
                value: amount,
            });

            expect(await weth.balanceOf(otherAccount.address)).to.equal(amount)

            await erc20Token.connect(otherAccount).deposit()
            expect(await erc20Token.balanceOf(otherAccount.address)).to.equal(amount)

            let re = await routerV1.calcSwapFee(0, 250, erc20Token.target, amount.toString())
            expect(re).to.equal(new BN(amount.toString()).mul(new BN(5)).div(new BN(10000)).toString())

            let swapID = await ctmSwapIDKeeper.calcSwapID(erc20Token.target, otherAccount.address, otherAccount.address, amount.toString(), "250", routerV1.target)

            await expect(routerV1.connect(otherAccount)["anySwapOut(address,address,uint256,uint256)"](erc20Token.target, otherAccount.address, amount.toString(), 250)).to.emit(routerV1, "LogAnySwapOut")
                .withArgs(erc20Token.target, otherAccount.address, otherAccount.address, amount.toString(), chainID, 250, re.toString(), swapID)

        });
        it("AnySwapOut Underlying", async function () {
            expect(await erc20Token.isMinter(routerV1.target)).to.equal(true)
            let amount = web3.utils.toNumber("1000000000000000000")
            await otherAccount.sendTransaction({
                to: weth.target,
                value: amount,
            });

            expect(await weth.balanceOf(otherAccount.address)).to.equal(amount)

            await weth.connect(otherAccount).approve(routerV1.target, amount.toString())
            expect(await weth.allowance(otherAccount.address, routerV1.target)).to.equal(amount.toString())

            let swapID = await ctmSwapIDKeeper.calcSwapID(erc20Token.target, otherAccount.address, otherAccount.address, amount.toString(), "250", routerV1.target)

            await expect(routerV1.connect(otherAccount)["anySwapOutUnderlying(address,address,uint256,uint256)"](erc20Token.target, otherAccount.address, amount.toString(), 250)).to.emit(routerV1, "LogAnySwapOut")
                .withArgs(erc20Token.target, otherAccount.address, otherAccount.address, amount.toString(), chainID, 250, 0, swapID)

        });
        it("AnySwapOut Native", async function () {
            expect(await erc20Token.isMinter(routerV1.target)).to.equal(true)
            let amount = web3.utils.toNumber("1000000000000000000")
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
                    },
                    {
                        "internalType": "uint256",
                        "name": "toChainID",
                        "type": "uint256"
                    }
                ],
                "name": "anySwapOutNative",
                "outputs": [],
                "stateMutability": "payable",
                "type": "function"
            }]
            let contract = new web3.eth.Contract(ABI);
            let calldata = contract.methods.anySwapOutNative(erc20Token.target, otherAccount.address, 250).encodeABI()

            let swapID = await ctmSwapIDKeeper.calcSwapID(erc20Token.target, otherAccount.address, otherAccount.address, amount.toString(), "250", routerV1.target)
            await expect(otherAccount.sendTransaction({
                to: routerV1.target,
                value: amount,
                data: calldata
            })).to.emit(routerV1, "LogAnySwapOut").withArgs(erc20Token.target, otherAccount.address, otherAccount.address, amount.toString(), chainID, 250, 0, swapID);
        });

        it("AnySwapIn", async function () {
            let amount = web3.utils.toNumber("1000000000000000000")
            let swapInMsg = {
                txs: "0x1234567890123456789012345678901234567890123456789012345678901234",
                token: erc20Token.target,
                to: otherAccount.address,
                fromChainID: 1,
                amount,
            }
            let swapID = await ctmSwapIDKeeper.calcSwapID(erc20Token.target, otherAccount.address, otherAccount.address, amount.toString(), "250", routerV1.target)
            await expect(routerV1.connect(owner)['anySwapIn(bytes32,address,address,uint256,uint256,string)'](swapID, swapInMsg.token, swapInMsg.to, swapInMsg.amount.toString(), swapInMsg.fromChainID, swapInMsg.txs)).to.emit(routerV1, "LogAnySwapIn")
                .withArgs(swapInMsg.token, swapInMsg.to, swapID, swapInMsg.amount.toString(), swapInMsg.fromChainID, chainID, swapInMsg.txs)

            await expect(routerV1.connect(owner)['anySwapIn(bytes32,address,address,uint256,uint256,string)'](swapID, swapInMsg.token, swapInMsg.to, swapInMsg.amount.toString(), swapInMsg.fromChainID, swapInMsg.txs))
                .to.be.revertedWith("swapID is completed")


            expect(await erc20Token.balanceOf(otherAccount.address)).to.equal(amount)
        });

        it("AnySwapIn Underlying", async function () {
            let amount = web3.utils.toNumber("1000000000000000000")
            let swapInMsg = {
                txs: "0x1234567890123456789012345678901234567890123456789012345678901234",
                token: erc20Token.target,
                to: owner.address,
                fromChainID: 1,
                amount,
            }

            await otherAccount.sendTransaction({
                to: weth.target,
                value: amount,
            });

            await erc20Token.connect(otherAccount).deposit()

            expect(await erc20Token.balanceOf(otherAccount.address)).to.equal(amount)

            let swapID = await ctmSwapIDKeeper.calcSwapID(erc20Token.target, otherAccount.address, otherAccount.address, amount.toString(), "250", routerV1.target)
            await expect(routerV1.connect(owner)['anySwapInUnderlying(bytes32,address,address,uint256,uint256,string)'](swapID, swapInMsg.token, swapInMsg.to, swapInMsg.amount.toString(), swapInMsg.fromChainID, swapInMsg.txs)).to.emit(routerV1, "LogAnySwapIn")
                .withArgs(swapInMsg.token, swapInMsg.to, swapID, swapInMsg.amount.toString(), swapInMsg.fromChainID, chainID, swapInMsg.txs)

            expect(await weth.balanceOf(owner.address)).to.equal(amount)
        });

        it("AnySwapIn Auto", async function () {
            let amount = web3.utils.toNumber("1000000000000000000")
            let swapInMsg = {
                txs: "0x1234567890123456789012345678901234567890123456789012345678901234",
                token: erc20Token.target,
                to: owner.address,
                fromChainID: 1,
                amount,
            }

            let swapID = await ctmSwapIDKeeper.calcSwapID(erc20Token.target, otherAccount.address, otherAccount.address, amount.toString(), "250", routerV1.target)
            await expect(routerV1.connect(owner).anySwapInAuto(swapID, swapInMsg.token, swapInMsg.to, swapInMsg.amount.toString(), swapInMsg.fromChainID, swapInMsg.txs)).to.emit(routerV1, "LogAnySwapIn")
                .withArgs(swapInMsg.token, swapInMsg.to, swapID, swapInMsg.amount.toString(), swapInMsg.fromChainID, chainID, swapInMsg.txs)

            expect(await erc20Token.balanceOf(owner.address)).to.equal(amount)
        });
        it("AnySwapIn Auto(Native)", async function () {
            let amount = web3.utils.toNumber("10000000000000000000")
            let swapInMsg = {
                txs: "0x1234567890123456789012345678901234567890123456789012345678901234",
                token: erc20Token.target,
                to: "0x1111111111111111111111111111111111111111",
                fromChainID: 1,
                amount,
            }

            await otherAccount.sendTransaction({
                to: weth.target,
                value: amount,
            });

            expect(await weth.balanceOf(otherAccount.address)).to.equal(amount)
            await erc20Token.connect(otherAccount).deposit()
            expect(await weth.balanceOf(erc20Token.target)).to.equal(amount)
            expect(await routerV1.wNATIVE()).to.equal(weth.target)


            let swapID = await ctmSwapIDKeeper.calcSwapID(erc20Token.target, otherAccount.address, otherAccount.address, amount.toString(), "250", routerV1.target)
            await expect(routerV1.connect(owner).anySwapInAuto(swapID, swapInMsg.token, swapInMsg.to, swapInMsg.amount.toString(), swapInMsg.fromChainID, swapInMsg.txs)).to.emit(routerV1, "LogAnySwapIn")
                .withArgs(swapInMsg.token, swapInMsg.to, swapID, swapInMsg.amount.toString(), swapInMsg.fromChainID, chainID, swapInMsg.txs)

            expect(await erc20Token.totalSupply()).to.equal(amount)

            expect(await ethers.provider.getBalance(swapInMsg.to)).to.equal(amount)

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
                to: routerV1.target,
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
                to: routerV1.target,
                value: amount,
                data: calldata
            })).to.emit(erc20Token, "Transfer").withArgs("0x0000000000000000000000000000000000000000", to, amount.toString());

            expect(await erc20Token.balanceOf(to)).to.equal(amount)
        });

        it("WithdrawNative", async function () {
            let amount = web3.utils.toNumber("10000000000000000000")
            let to = "0x1111111111111111111111111111111111111112"
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
                to: routerV1.target,
                value: amount,
                data: calldata
            })
            expect(await erc20Token.balanceOf(owner.address)).to.equal(amount)

            await expect(routerV1.connect(owner).withdrawNative(erc20Token.target, amount.toString(), to)).to.emit(erc20Token, "Transfer")
                .withArgs(owner.address, "0x0000000000000000000000000000000000000000", amount.toString());

            expect(await erc20Token.balanceOf(owner.address)).to.equal(0)
            expect(await ethers.provider.getBalance(to)).to.equal(amount)
        });

        it("Operator SwapIn", async function () {
            let amount = web3.utils.toNumber("1000000000000000000")
            let swapInMsg = {
                txs: "0x1234567890123456789012345678901234567890123456789012345678901234",
                token: erc20Token.target,
                to: otherAccount.address,
                fromChainID: 1,
                amount,
            }
            let swapID = await ctmSwapIDKeeper.calcSwapID(erc20Token.target, otherAccount.address, otherAccount.address, amount.toString(), "250", routerV1.target)
            await expect(routerV1.connect(otherAccount)['anySwapIn(bytes32,address,address,uint256,uint256,string)'](swapID, swapInMsg.token, swapInMsg.to, swapInMsg.amount.toString(), swapInMsg.fromChainID, swapInMsg.txs))
                .to.be.revertedWith("CtmDaoV1ERC20: AUTH FORBIDDEN")

            await routerV1.connect(owner).addOperator(otherAccount.address)
            let ops = await routerV1.getAllOperators()
            expect(ops[0]).to.equal(owner.address)
            expect(ops[1]).to.equal(otherAccount.address)

            await expect(routerV1.connect(otherAccount)['anySwapIn(bytes32,address,address,uint256,uint256,string)'](swapID, swapInMsg.token, swapInMsg.to, swapInMsg.amount.toString(), swapInMsg.fromChainID, swapInMsg.txs)).to.emit(routerV1, "LogAnySwapIn")
                .withArgs(swapInMsg.token, swapInMsg.to, swapID, swapInMsg.amount.toString(), swapInMsg.fromChainID, chainID, swapInMsg.txs)


            await routerV1.connect(owner).revokeOperator(otherAccount.address)
            ops = await routerV1.getAllOperators()
            expect(ops.length).to.equal(1)

            await expect(routerV1.connect(otherAccount)['anySwapIn(bytes32,address,address,uint256,uint256,string)'](swapID, swapInMsg.token, swapInMsg.to, swapInMsg.amount.toString(), swapInMsg.fromChainID, swapInMsg.txs))
                .to.be.revertedWith("CtmDaoV1ERC20: AUTH FORBIDDEN")
        });
    });

});
