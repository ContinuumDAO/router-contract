const { expect } = require("chai");
const { Web3 } = require('web3');
let web3 = new Web3(Web3.givenProvider);
const BN = require('bn.js');

describe("C3Caller", function () {
    let owner
    let otherAccount
    let c3Caller


    async function deployC3Caller() {
        // Contracts are deployed using the first signer/account by default
        const [_owner, _otherAccount] = await ethers.getSigners();

        const C3Caller = await ethers.getContractFactory("C3Caller");
        c3Caller = await C3Caller.deploy(_owner);

        await c3Caller.addRouter(_owner)

        owner = _owner
        otherAccount = _otherAccount
    }


    beforeEach(async () => {
        await deployC3Caller()
    })

    describe("C3Caller", function () {
        it("constructor", async function () {
            expect(await c3Caller.mpc()).to.equal(owner.address)
            expect(await c3Caller.isRouter(owner.address)).to.equal(true)
        });

        it("initAppConfig", async function () {
            let appID = web3.utils.randomHex(12)
            await expect(c3Caller.connect(owner).initAppConfig(appID, otherAccount.address, owner.address, 1, [owner.address])).to.emit(c3Caller, "SetAppConfig")
                .withArgs(appID, otherAccount.address, owner.address, 1)

            let appID2 = web3.utils.randomHex(12)
            await expect(c3Caller.connect(owner).initAppConfig(appID2, otherAccount.address, owner.address, 3, [owner.address])).to.be.revertedWith("C3Call: _flags is invalid")
        });

        it("setDefaultSrcFees", async function () {
            await c3Caller.connect(owner).setDefaultSrcFees([1, 2], [100000000, 100000000], [10000000, 10000000])

            let dfee = await c3Caller.srcDefaultFees(1)
            expect(dfee[0]).to.equal(100000000)
            expect(dfee[1]).to.equal(10000000)

        });

        it("calcSrcFees", async function () {
            let appID = web3.utils.randomHex(12)
            await c3Caller.connect(owner).initAppConfig(appID, otherAccount.address, owner.address, 1, [owner.address])

            await c3Caller.connect(owner).setDefaultSrcFees([1, 2], [100000000, 200000000], [10000000, 20000000])

            expect(await c3Caller.calcSrcFees(otherAccount.address, 1, 366)).to.equal(100000000 + 366 * 10000000)
            expect(await c3Caller.calcSrcFeesByApp(appID, 1, 366)).to.equal(100000000 + 366 * 10000000)
            expect(await c3Caller.calcSrcFeesByApp(appID, 2, 366)).to.equal(200000000 + 366 * 20000000)

        });

        it("setCustomSrcFees", async function () {
            let appID = web3.utils.randomHex(12)
            await c3Caller.connect(owner).initAppConfig(appID, otherAccount.address, owner.address, 1, [owner.address])

            await c3Caller.connect(owner).setDefaultSrcFees([1, 2], [100000000, 200000000], [10000000, 20000000])
            await c3Caller.connect(owner).setCustomSrcFees(otherAccount.address, [1, 2], [90000000, 210000000], [11000000, 19000000])

            expect(await c3Caller.calcSrcFees(otherAccount.address, 1, 366)).to.equal(100000000 + 366 * 11000000)
            expect(await c3Caller.calcSrcFeesByApp(appID, 2, 366)).to.equal(210000000 + 366 * 20000000)

        });

        it("paySrcFees", async function () {
            let appID = web3.utils.randomHex(12)
            await c3Caller.connect(owner).initAppConfig(appID, otherAccount.address, owner.address, 1, [owner.address])

            let ABI = [{
                "inputs": [
                    {
                        "internalType": "address",
                        "name": "_sender",
                        "type": "address"
                    },
                    {
                        "internalType": "uint256",
                        "name": "_fees",
                        "type": "uint256"
                    }
                ],
                "name": "paySrcFees",
                "outputs": [],
                "stateMutability": "payable",
                "type": "function"
            }]
            let contract = new web3.eth.Contract(ABI);
            let calldata = contract.methods.paySrcFees(otherAccount.address, 1000000000).encodeABI()
            await expect(owner.sendTransaction({
                to: c3Caller.target,
                value: 1000000000,
                data: calldata
            })).to.emit(c3Caller, "IncrFee").withArgs(appID, 1000000000, 1000000000)

            expect(await c3Caller.accruedFees()).to.equal(1000000000)

            await c3Caller.connect(owner).withdrawFees()

            expect(await c3Caller.accruedFees()).to.equal(0)
        });
    });

});


