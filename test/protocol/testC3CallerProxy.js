const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("CallerProxy", function () {

    let oldc3CallerProxy
    let owner
    let otherAccount
    let c3Caller

    async function deployProxy() {
        // Contracts are deployed using the first signer/account by default
        const [_owner, _otherAccount] = await ethers.getSigners();

        const C3SwapIDKeeper = await ethers.getContractFactory("contracts/protocol/C3SwapIDKeeper.sol:C3SwapIDKeeper");
        let c3SwapIDKeeper = await C3SwapIDKeeper.deploy(_owner.address);

        const C3Caller = await ethers.getContractFactory("contracts/protocol/C3Caller.sol:C3Caller");
        c3Caller = await C3Caller.deploy(_owner.address, c3SwapIDKeeper.target);

        const C3CallerProxy = await ethers.getContractFactory("C3CallerProxy");
        oldc3CallerProxy = await upgrades.deployProxy(C3CallerProxy, [_owner.address, c3Caller.target], { initializer: 'initialize', kind: 'uups' });

        await c3SwapIDKeeper.addSupportedCaller(c3Caller.target)

        await c3Caller.addOperator(oldc3CallerProxy.target)

        owner = _owner
        otherAccount = _otherAccount
    }

    beforeEach(async () => {
        await deployProxy()
    })

    describe("Oldc3CallerProxy", function () {
        it("constructor", async function () {
            expect(await oldc3CallerProxy.owner()).to.equal(owner.address)
            expect(await oldc3CallerProxy.mpc()).to.equal(owner.address)
            expect(await oldc3CallerProxy.isOperator(owner.address)).to.equal(true)
            expect(await oldc3CallerProxy.c3caller()).to.equal(c3Caller.target)
        });

        it("Upgrade", async function () {
            const C3CallerProxyUpgrade = await ethers.getContractFactory("C3CallerProxyUpgrade");
            let upgradedContract = await upgrades.upgradeProxy(oldc3CallerProxy, C3CallerProxyUpgrade);

            expect(await upgradedContract.owner()).to.equal(owner.address)
            expect(await upgradedContract.mpc()).to.equal(owner.address)
            expect(await upgradedContract.isOperator(owner.address)).to.equal(true)
            expect(await upgradedContract.c3caller()).to.equal(c3Caller.target)

            await upgradedContract.setCallerVersion(1, c3Caller.target)
            await upgradedContract.setCallerVersion(2, c3Caller.target)

            expect(await upgradedContract.c3callerWithVersion(2)).to.equal(c3Caller.target)

        });
    });
});