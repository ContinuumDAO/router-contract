const { expect } = require("chai");
const { Web3 } = require('web3');
let web3 = new Web3(Web3.givenProvider);
const BN = require('bn.js');

describe("C3DappManager", function () {
    let c3DappManager
    let erc20Token
    let weth
    let owner
    let otherAccount

    async function deploy() {
        const [_owner, _otherAccount] = await ethers.getSigners();
        const WETH = await ethers.getContractFactory("WETH");
        weth = await WETH.deploy();


        const C3DappManager = await ethers.getContractFactory("C3DappManager");
        c3DappManager = await C3DappManager.deploy();

        owner = _owner
        otherAccount = _otherAccount
    }

    async function deployC3ERC20(name, symbol, decimals, underlying, vault) {
        const C3ERC20 = await ethers.getContractFactory("TheiaERC20");
        erc20Token = await C3ERC20.deploy(name, symbol, decimals, underlying, vault);
    }


    beforeEach(async () => {
        await deploy()
        await deployC3ERC20("ctmETH", "ctmETH", 18, weth.target, owner.address)
    })

    describe("functions", function () {
        it("setFeeCurrencies", async function () {
            await expect(c3DappManager.setFeeCurrencies([weth.target], [100000000]))
                .to.emit(c3DappManager, "SetFeeConfig").withArgs(weth.target, "0", 100000000);

            await expect(c3DappManager.disableFeeCurrency(weth.target))
                .to.emit(c3DappManager, "SetFeeConfig").withArgs(weth.target, "0", 0);
        });


        it("setSpeFeeConfigByChain", async function () {
            await expect(c3DappManager.setSpeFeeConfigByChain(weth.target, "1", "200000000"))
                .to.emit(c3DappManager, "SetFeeConfig").withArgs(weth.target, "1", 200000000);
        });

        it("initDappConfig", async function () {
            await expect(c3DappManager.setFeeCurrencies([weth.target], [100000000]))
                .to.emit(c3DappManager, "SetFeeConfig").withArgs(weth.target, "0", 100000000);

            let dappID = await c3DappManager.dappID();
            let nextID = new BN(dappID).add(new BN(1)).toString()
            await expect(c3DappManager.connect(otherAccount).initDappConfig(weth.target, "test.com", "admin@test.com", [otherAccount.address]))
                .to.emit(c3DappManager, "SetDAppConfig").withArgs(nextID, otherAccount.address, weth.target, "test.com", "admin@test.com")
                .to.emit(c3DappManager, "SetDAppAddr").withArgs(nextID, [otherAccount.address]);

            await expect(c3DappManager.addDappAddr(nextID, [owner.address]))
                .to.emit(c3DappManager, "SetDAppAddr").withArgs(nextID, [owner.address]);

            await expect(c3DappManager.delWhitelists(nextID, [owner.address]))
                .to.emit(c3DappManager, "SetDAppAddr").withArgs(0, [owner.address]);

            await expect(c3DappManager.connect(otherAccount).updateDAppConfig(nextID, weth.target, "test1.com", "admin@test1.com"))
                .to.emit(c3DappManager, "SetDAppConfig").withArgs(nextID, otherAccount.address, weth.target, "test1.com", "admin@test1.com");

            await expect(c3DappManager.connect(otherAccount).updateDappByGov(nextID, weth.target, 10000000))
                .to.be.revertedWith("C3Gov: only Operator");

        });

        it("resetAdmin", async function () {
            await expect(c3DappManager.setFeeCurrencies([weth.target], [100000000]))
                .to.emit(c3DappManager, "SetFeeConfig").withArgs(weth.target, "0", 100000000);
            let dappID = await c3DappManager.dappID();
            let nextID = new BN(dappID).add(new BN(1)).toString()
            c3DappManager.connect(otherAccount).initDappConfig(weth.target, "test.com", "admin@test.com", [otherAccount.address])

            c3DappManager.connect(otherAccount).resetAdmin(nextID, owner.address);

            await expect(c3DappManager.updateDAppConfig(nextID, weth.target, "test1.com", "admin@test1.com"))
                .to.emit(c3DappManager, "SetDAppConfig").withArgs(nextID, owner.address, weth.target, "test1.com", "admin@test1.com");

        });


        it("deposit and withdraw", async function () {
            await c3DappManager.setFeeCurrencies([weth.target, erc20Token.target], [100000000, 2000000000])
            let dappID = await c3DappManager.dappID();
            let nextID = new BN(dappID).add(new BN(1)).toString()
            await c3DappManager.connect(otherAccount).initDappConfig(erc20Token.target, "test.com", "admin@test.com", [otherAccount.address])

            let amount = new BN("10000000000000000000000")
            await erc20Token.mint(otherAccount, amount.toString());

            await erc20Token.connect(otherAccount).approve(c3DappManager.target, amount.toString())

            await expect(c3DappManager.connect(otherAccount).deposit(nextID, erc20Token.target, amount.toString()))
                .to.emit(c3DappManager, "Deposit").withArgs(nextID, erc20Token.target, amount.toString(), amount.toString());

            expect(await erc20Token.balanceOf(otherAccount)).to.equal("0");
            expect(await erc20Token.balanceOf(c3DappManager)).to.equal(amount.toString());

            await expect(c3DappManager.connect(otherAccount).withdraw(nextID, erc20Token.target, amount.toString()))
                .to.emit(c3DappManager, "Withdraw").withArgs(nextID, erc20Token.target, amount.toString(), 0);


            expect(await erc20Token.balanceOf(otherAccount)).to.equal(amount.toString());
        });


        it("charging", async function () {
            await c3DappManager.setFeeCurrencies([weth.target, erc20Token.target], [100000000, 2000000000])
            let dappID = await c3DappManager.dappID();
            let nextID = new BN(dappID).add(new BN(1)).toString()
            await c3DappManager.connect(otherAccount).initDappConfig(erc20Token.target, "test.com", "admin@test.com", [otherAccount.address])

            let amount = new BN("10000000000000000000000")
            await erc20Token.mint(otherAccount, amount.toString());

            await erc20Token.connect(otherAccount).approve(c3DappManager.target, amount.toString())

            await expect(c3DappManager.connect(otherAccount).deposit(nextID, erc20Token.target, amount.toString()))
                .to.emit(c3DappManager, "Deposit").withArgs(nextID, erc20Token.target, amount.toString(), amount.toString());


            await expect(c3DappManager.connect(otherAccount).charging([nextID], [erc20Token.target], [amount.toString()]))
                .to.revertedWith("C3Gov: only Operator");

            await expect(c3DappManager.charging([nextID], [erc20Token.target], [amount.div(new BN(2)).toString()]))
                .to.emit(c3DappManager, "Charging").withArgs(nextID, erc20Token.target, amount.div(new BN(2)).toString(), amount.div(new BN(2)).toString(), amount.div(new BN(2)).toString());

            await expect(c3DappManager.charging([nextID], [erc20Token.target], [amount.toString()]))
                .to.emit(c3DappManager, "Charging").withArgs(nextID, erc20Token.target, amount.toString(), amount.div(new BN(2)).toString(), "0");
        });


        it.only("addTxSender", async function () {
            await c3DappManager.setFeeCurrencies([weth.target, erc20Token.target], [100000000, 2000000000])
            let dappID = await c3DappManager.dappID();
            let nextID = new BN(dappID).add(new BN(1)).toString()
            await expect(c3DappManager.connect(otherAccount).initDappConfig(weth.target, "test.com", "admin@test.com", []))
                .to.emit(c3DappManager, "SetDAppConfig").withArgs(nextID, otherAccount.address, weth.target, "test.com", "admin@test.com")

            await expect(c3DappManager.connect(otherAccount).addTxSender(nextID, ["addr"], ["pubkey"]))
                .to.emit(c3DappManager, "AddMpcAddr").withArgs(nextID, "addr", "pubkey");

            console.log(await c3DappManager.getTxSenders(nextID))

            await expect(c3DappManager.connect(otherAccount).removeTxSender(nextID, ["addr"]))
                .to.emit(c3DappManager, "DelMpcAddr").withArgs(nextID, "addr", "pubkey");

            console.log(await c3DappManager.getTxSenders(nextID))
        });
    });

});
